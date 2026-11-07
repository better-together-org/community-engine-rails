# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::QuotaGrant do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:owner) { create(:better_together_person) }
  let(:granter) { create(:better_together_person) }

  def build_grant(**)
    described_class.new(owner:, quota_type: 'media_storage', limit: 1_000, granted_by: granter, **)
  end

  describe 'validations' do
    it 'is valid with an owner, a known quota_type, and a non-negative limit' do
      expect(build_grant).to be_valid
    end

    it 'rejects an owner that is not a registered Quotas::Owner' do
      grant = build_grant
      grant.owner = BetterTogether::Robot.new
      expect(grant).not_to be_valid
      expect(grant.errors[:owner_type]).to be_present
    end

    it 'rejects an unknown quota_type' do
      grant = build_grant(quota_type: 'not_a_real_type')
      expect(grant).not_to be_valid
    end

    it 'rejects a negative limit' do
      grant = build_grant(limit: -1)
      expect(grant).not_to be_valid
    end

    it 'allows a nil granted_by' do
      grant = build_grant(granted_by: nil)
      expect(grant).to be_valid
    end

    it 'rejects a granted_by outside the actor type allow-list' do
      grant = build_grant
      grant.granted_by = create(:better_together_community)
      expect(grant).not_to be_valid
    end
  end

  describe '.active scope' do
    it 'includes a grant with no expiry' do
      grant = build_grant(expires_at: nil).tap(&:save!)
      expect(described_class.active).to include(grant)
    end

    it 'includes a grant that has not expired yet' do
      grant = build_grant(expires_at: 1.day.from_now).tap(&:save!)
      expect(described_class.active).to include(grant)
    end

    it 'excludes a grant that has already expired' do
      grant = build_grant(expires_at: 1.day.ago).tap(&:save!)
      expect(described_class.active).not_to include(grant)
    end
  end

  describe 'BetterTogether::Quota#effective_limit' do
    it 'falls back to the stored limit when no grant exists' do
      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'quota_grant_spec:settle'
      )
      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')

      expect(quota.effective_limit).to eq(quota.limit)
    end

    it 'uses the active grant limit when it is higher than the stored limit' do
      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'quota_grant_spec:settle2'
      )
      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      build_grant(owner:, limit: quota.limit + 1_000_000).save!

      expect(quota.effective_limit).to eq(quota.limit + 1_000_000)
    end

    it 'ignores an expired grant' do
      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'quota_grant_spec:settle3'
      )
      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      build_grant(owner:, limit: quota.limit + 1_000_000, expires_at: 1.day.ago).save!

      expect(quota.effective_limit).to eq(quota.limit)
    end
  end
end
