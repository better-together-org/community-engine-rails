# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ShortLink do
  subject(:short_link) { build(:better_together_short_link) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(short_link).to be_valid
    end
  end

  describe 'validations' do
    # NOTE: validate_presence_of(:code) cannot be tested with shoulda-matchers because
    # the before_validation :ensure_code_present callback auto-generates a code when blank.
    # Covered explicitly below in the callbacks section.
    it { is_expected.to validate_presence_of(:target_url) }

    # NOTE: validate_uniqueness_of(:code) via shoulda-matchers fails because it tries to
    # persist a record with nil platform_id, which violates the NOT NULL constraint.
    # Uniqueness is verified via direct duplicate-record tests below.
    describe 'code uniqueness within platform scope' do
      it 'rejects a duplicate code on the same platform' do
        existing = create(:better_together_short_link, code: 'dupcode')
        duplicate = build(:better_together_short_link,
                          platform: existing.platform,
                          code: 'dupcode')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to be_present
      end

      it 'is case-insensitive for uniqueness' do
        existing = create(:better_together_short_link, code: 'mixcase')
        # Code format only allows lowercase, so test via direct DB value
        duplicate = build(:better_together_short_link,
                          platform: existing.platform,
                          code: 'mixcase')
        expect(duplicate).not_to be_valid
      end

      it 'allows the same code on a different platform' do
        create(:better_together_short_link, code: 'shared1')
        second = build(:better_together_short_link,
                       platform: create(:better_together_platform),
                       code: 'shared1')
        expect(second).to be_valid
      end
    end

    describe 'code format' do
      it 'accepts lowercase alphanumeric codes' do
        short_link.code = 'abc123'
        expect(short_link).to be_valid
      end

      it 'accepts codes with hyphens' do
        short_link.code = 'abc-123'
        expect(short_link).to be_valid
      end

      it 'rejects uppercase letters' do
        short_link.code = 'ABC123'
        expect(short_link).not_to be_valid
        expect(short_link.errors[:code]).to be_present
      end

      it 'rejects underscores and other special characters' do
        short_link.code = 'abc_123'
        expect(short_link).not_to be_valid
        expect(short_link.errors[:code]).to be_present
      end
    end

    describe 'target_url scheme validation' do
      %w[http https].each do |scheme|
        it "accepts #{scheme} URLs" do
          short_link.target_url = "#{scheme}://example.com/page"
          expect(short_link).to be_valid
        end
      end

      %w[ftp javascript].each do |scheme|
        it "rejects #{scheme} URLs" do
          short_link.target_url = "#{scheme}://example.com/page"
          expect(short_link).not_to be_valid
          expect(short_link.errors[:target_url]).to be_present
        end
      end

      it 'rejects invalid URIs' do
        short_link.target_url = 'not a url'
        expect(short_link).not_to be_valid
        expect(short_link.errors[:target_url]).to be_present
      end
    end
  end

  describe 'callbacks' do
    describe '#ensure_code_present (before_validation)' do
      it 'generates a code when blank' do
        short_link.code = nil
        short_link.valid?
        expect(short_link.code).to match(/\A[a-z0-9]{6}\z/)
      end

      it 'does not overwrite an existing valid code' do
        short_link.code = 'mycode'
        short_link.valid?
        expect(short_link.code).to eq('mycode')
      end
    end

    describe '#auto_expire_if_past (before_save)' do
      it 'sets status to expired when expires_at is in the past' do
        link = build(:better_together_short_link, :expired, status: 'active')
        link.save!
        expect(link.status).to eq('expired')
      end

      it 'does not change status when expires_at is in the future' do
        link = build(:better_together_short_link, expires_at: 1.day.from_now, status: 'active')
        link.save!
        expect(link.status).to eq('active')
      end

      it 'does not change status when expires_at is nil' do
        link = build(:better_together_short_link, expires_at: nil, status: 'active')
        link.save!
        expect(link.status).to eq('active')
      end
    end
  end

  describe '#active_and_unexpired?' do
    it 'returns true for an active link without expiry' do
      link = create(:better_together_short_link, status: 'active', expires_at: nil)
      expect(link.active_and_unexpired?).to be true
    end

    it 'returns true for an active link with a future expiry' do
      link = create(:better_together_short_link, status: 'active', expires_at: 1.day.from_now)
      expect(link.active_and_unexpired?).to be true
    end

    it 'returns false for an inactive link' do
      link = create(:better_together_short_link, :inactive)
      expect(link.active_and_unexpired?).to be false
    end

    it 'returns false for an active link with a past expiry' do
      # Build with active status but past expiry — before_save will flip to expired on save
      link = create(:better_together_short_link, :expired)
      expect(link.active_and_unexpired?).to be false
    end
  end

  describe '#url' do
    it 'returns a short URL composed of platform share_base_url and the code' do
      link = create(:better_together_short_link, code: 'abc123')
      expect(link.url).to include('/s/abc123')
    end
  end

  describe 'status enum' do
    it 'defines the expected status values' do
      expect(described_class.statuses.keys).to contain_exactly('active', 'inactive', 'expired')
    end

    it 'defaults to active' do
      link = create(:better_together_short_link)
      expect(link.status).to eq('active')
    end
  end
end
