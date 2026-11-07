# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::Meter do
  include_context 'with entitlement fixtures'

  it 'reads the limit and what is used, without changing anything' do
    BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: buyer)
    BetterTogether::Quota.find_by!(owner: buyer, quota_type: 'media_storage').update!(limit: 1_000)
    BetterTogether::Quotas.settle!(type: 'media_storage', owner: buyer, amount: 250, idempotency_key: 'meter-1')

    reading = described_class.for(owner: buyer, type: 'media_storage')

    expect(reading).to have_attributes(limit: 1_000, used: 250, remaining: 750, percent: 25)
    expect(reading).not_to be_over
    expect { described_class.for(owner: buyer, type: 'media_storage') }.not_to change(BetterTogether::QuotaUsage, :count)
  end

  it 'is exact when over the limit, where the framework only says nothing is left' do
    BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: buyer)
    BetterTogether::Quota.find_by!(owner: buyer, quota_type: 'media_storage').update!(limit: 100)
    BetterTogether::Quotas.settle!(type: 'media_storage', owner: buyer, amount: 400, idempotency_key: 'meter-2')

    reading = described_class.for(owner: buyer, type: 'media_storage')

    expect(reading).to have_attributes(used: 400, remaining: 0, percent: 100)
    expect(reading).to be_over
  end

  it 'has no limit for a quota with none' do
    reading = described_class::Reading.new(limit: nil, used: 5)

    expect(reading).to be_unlimited
    expect(reading).to have_attributes(remaining: nil, percent: 0)
    expect(reading).not_to be_over
  end
end
