# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::Handlers::QuotaAllowance do
  include_context 'with entitlement fixtures'

  let(:parameters) { { 'quota_type' => 'media_storage', 'amount' => '5000' } }
  let(:handler) { described_class.new(parameters, platform: host_platform) }

  it 'accepts a known quota type and a positive amount, and refuses anything else' do
    expect(handler.errors).to be_empty
    expect(described_class.new(parameters.merge('quota_type' => 'gold'), platform: host_platform).errors).to eq([:quota_unknown])
    ['0', '-5', 'lots', nil].each do |amount|
      expect(described_class.new(parameters.merge('amount' => amount), platform: host_platform).errors).to eq([:amount_invalid])
    end
  end

  it 'is for people, communities and the platform: anyone who owns a quota' do
    expect([buyer, community, host_platform].map { |owner| handler.applies_to?(owner) }).to all(be(true))
    expect(handler.applies_to?(create(:better_together_billing_plan))).to be(false)
  end

  it 'names the grant by the quota' do
    expect(handler.key).to eq('quota_allowance:media_storage')
  end

  it 'gives an amount of the quota, with nothing behind it to find or remove' do
    entitlement = make_entitlement

    applied = handler.apply(entitlement)

    expect(applied).to have_attributes(owned: true, record: nil, quota_type: 'media_storage', amount: 5000)
    expect(handler.release(nil)).to be_nil
  end
end
