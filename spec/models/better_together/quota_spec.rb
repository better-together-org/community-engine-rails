# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quota do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:owner) { create(:better_together_person) }

  describe '#current_period_key' do
    it 'returns "cumulative" for a cumulative-period quota' do
      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'quota_spec:cumulative'
      )
      quota = described_class.find_by(owner:, quota_type: 'media_storage')

      expect(quota.current_period_key).to eq('cumulative')
    end

    it 'returns the current month for a monthly-period quota' do
      BetterTogether::Quotas.settle!(
        type: 'ai_translation_tokens', owner:, amount: 1, idempotency_key: 'quota_spec:monthly'
      )
      quota = described_class.find_by(owner:, quota_type: 'ai_translation_tokens')

      expect(quota.current_period_key).to eq(Time.current.strftime('%Y-%m'))
    end
  end

  describe '#current_balance' do
    it 'returns the QuotaBalance row for the current period' do
      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 500, idempotency_key: 'quota_spec:balance'
      )
      quota = described_class.find_by(owner:, quota_type: 'media_storage')

      expect(quota.current_balance).to eq(
        BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative')
      )
      expect(quota.current_balance.consumed).to eq(500)
    end

    it 'returns nil when no balance row exists yet for the current period' do
      quota = described_class.create!(
        owner:, quota_type: 'media_storage', limit: 1024, period: 'cumulative'
      )

      expect(quota.current_balance).to be_nil
    end
  end
end
