# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonMessagingGrant do
  let(:person_a) { create(:better_together_person) }
  let(:person_b) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with distinct grantor and grantee' do
      grant = described_class.new(grantor: person_a, grantee: person_b)
      expect(grant).to be_valid
    end

    it 'is invalid when grantor and grantee are the same person' do
      grant = described_class.new(grantor: person_a, grantee: person_a)
      expect(grant).not_to be_valid
      expect(grant.errors[:grantee_id]).to be_present
    end

    it 'enforces uniqueness of the grantor/grantee pair' do
      described_class.create!(grantor: person_a, grantee: person_b)
      duplicate = described_class.new(grantor: person_a, grantee: person_b)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:grantor_id]).to be_present
    end

    it 'allows the reverse direction independently' do
      described_class.create!(grantor: person_a, grantee: person_b)
      reverse = described_class.new(grantor: person_b, grantee: person_a)
      expect(reverse).to be_valid
    end
  end

  describe 'platform scoping' do
    let(:platform_a) { create(:better_together_platform, :public, host: false) }
    let(:platform_b) { create(:better_together_platform, :public, host: false) }

    it 'defaults to the current/host platform when none is given' do
      grant = described_class.create!(grantor: person_a, grantee: person_b)
      expect(grant.platform_id).to be_present
    end

    it 'allows the same grantor/grantee pair to hold independent grants on different platforms' do
      described_class.create!(grantor: person_a, grantee: person_b, platform: platform_a)
      other_platform_grant = described_class.new(grantor: person_a, grantee: person_b, platform: platform_b)

      expect(other_platform_grant).to be_valid
    end

    it 'still rejects a duplicate grantor/grantee pair on the same platform' do
      described_class.create!(grantor: person_a, grantee: person_b, platform: platform_a)
      duplicate = described_class.new(grantor: person_a, grantee: person_b, platform: platform_a)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:grantor_id]).to be_present
    end
  end
end
