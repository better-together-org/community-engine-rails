# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::QuotaAllowances do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  def entitlement_with_allowance(beneficiary, amount, status: 'active')
    # Each on its own plan: a person can have one live entitlement per plan.
    plan = create(:better_together_billing_plan, processor: nil, processor_price_id: nil, accepted_payment_methods: %w[cash])
    entitlement = make_entitlement(beneficiary:, plan:)
    entitlement.update_columns(status:) # rubocop:disable Rails/SkipsModelValidations
    entitlement.grants.create!(platform_id: host_platform.id, grant_key: 'quota_allowance:media_storage', kind: 'quota_allowance',
                               parameters: {}, quota_type: 'media_storage', amount:, owned: true)
    entitlement
  end

  it 'adds up the live allowances of an owner for a quota type' do
    entitlement_with_allowance(buyer, 500)
    entitlement_with_allowance(buyer, 250, status: 'grace')

    expect(described_class.amount(owner: buyer, type: 'media_storage')).to eq(750)
    expect(described_class.amount(owner: buyer, type: 'ai_translation_tokens')).to eq(0)
  end

  it 'leaves out allowances that lapsed or were revoked, and other owners\' allowances' do
    entitlement_with_allowance(buyer, 500, status: 'lapsed')
    entitlement_with_allowance(buyer, 500, status: 'revoked')
    entitlement_with_allowance(create(:better_together_person), 900)

    expect(described_class.amount(owner: buyer, type: 'media_storage')).to eq(0)
  end

  it 'leaves out an allowance that was released' do
    entitlement = entitlement_with_allowance(buyer, 500)
    entitlement.grants.first.release!

    expect(described_class.amount(owner: buyer, type: 'media_storage')).to eq(0)
  end

  it 'makes only a community with an allowance a pool for that quota' do
    entitlement_with_allowance(community, 500)

    expect(described_class.pool?(owner: community, type: 'media_storage')).to be(true)
    expect(described_class.pool?(owner: community, type: 'ai_translation_tokens')).to be(false)
    expect(described_class.pool?(owner: create(:better_together_community, platform: host_platform), type: 'media_storage')).to be(false)
  end

  it 'never makes a person a pool, however large their allowance' do
    entitlement_with_allowance(buyer, 500)

    expect(described_class.pool?(owner: buyer, type: 'media_storage')).to be(false)
  end

  it 'is the provider the quota framework asks, so the limit is the default plus the allowance' do
    entitlement_with_allowance(buyer, 500)
    default = BetterTogether::Quotas::Type.find('media_storage').default_limit(buyer)

    expect(BetterTogether::Quotas.effective_limit(BetterTogether::Quotas::Type.find('media_storage'), buyer)).to eq(default + 500)
  end

  it 'keeps usage when an allowance goes: the limit drops, nothing is deleted' do
    entitlement = entitlement_with_allowance(buyer, 5_000)
    BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: buyer)
    BetterTogether::Quotas.settle!(type: 'media_storage', owner: buyer, amount: 100, idempotency_key: 'used-1')

    entitlement.grants.first.release!
    BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: buyer)

    quota = BetterTogether::Quota.find_by!(owner: buyer, quota_type: 'media_storage')
    expect(quota.limit).to eq(BetterTogether::Quotas::Type.find('media_storage').default_limit(buyer))
    expect(quota.quota_usages.sum(:amount)).to eq(100)
  end

  describe 'with billing switched off' do
    around do |example|
      previous = ENV.delete('BT_BILLING_ENABLED')
      example.run
    ensure
      ENV['BT_BILLING_ENABLED'] = previous if previous
    end

    it 'answers without touching the entitlement tables' do
      entitlement_with_allowance(buyer, 500)
      community = create(:better_together_community)
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/billing_entitlement/) }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        expect(described_class.amount(owner: buyer, type: 'media_storage')).to eq(0)
        expect(described_class.pool?(owner: community, type: 'media_storage')).to be(false)
      end

      expect(queries).to be_empty
    end
  end
end
