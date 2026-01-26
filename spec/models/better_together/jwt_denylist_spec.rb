# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe JwtDenylist do
    describe 'factory' do
      it 'creates a valid jwt denylist entry' do
        entry = build(:jwt_denylist)
        expect(entry).to be_valid
      end

      it 'creates entries with different expiration times' do
        %i[expired recently_expired expires_soon long_lived].each do |trait|
          entry = build(:jwt_denylist, trait)
          expect(entry).to be_valid
        end
      end
    end

    describe 'devise jwt integration' do
      it 'includes Devise::JWT::RevocationStrategies::Denylist' do
        expect(described_class.included_modules).to include(Devise::JWT::RevocationStrategies::Denylist)
      end

      it 'has correct table name' do
        expect(described_class.table_name).to eq('better_together_jwt_denylists')
      end
    end

    describe 'database schema' do
      it 'has jti column' do
        entry = create(:jwt_denylist)
        expect(entry).to respond_to(:jti)
        expect(entry.jti).to be_present
      end

      it 'has exp column' do
        entry = create(:jwt_denylist)
        expect(entry).to respond_to(:exp)
        expect(entry.exp).to be_present
      end

      it 'has standard bt_table columns' do
        entry = create(:jwt_denylist)
        expect(entry).to respond_to(:id)
        expect(entry).to respond_to(:lock_version)
        expect(entry).to respond_to(:created_at)
        expect(entry).to respond_to(:updated_at)
      end
    end

    describe 'token revocation' do
      it 'stores unique jti values' do
        jti1 = SecureRandom.uuid
        jti2 = SecureRandom.uuid

        entry1 = create(:jwt_denylist, jti: jti1)
        entry2 = create(:jwt_denylist, jti: jti2)

        expect(entry1.jti).not_to eq(entry2.jti)
      end

      it 'stores expiration time' do
        exp_time = 2.hours.from_now
        entry = create(:jwt_denylist, exp: exp_time)

        expect(entry.exp).to be_within(1.second).of(exp_time)
      end

      it 'can store expired tokens' do
        entry = create(:jwt_denylist, :expired)

        expect(entry.exp).to be < Time.current
      end
    end

    describe 'queries' do
      it 'can find entries by jti' do
        jti = SecureRandom.uuid
        entry = create(:jwt_denylist, jti: jti)

        found = described_class.find_by(jti: jti)
        expect(found).to eq(entry)
      end

      it 'returns nil for non-existent jti' do
        found = described_class.find_by(jti: 'non-existent-jti')
        expect(found).to be_nil
      end
    end
  end
end
