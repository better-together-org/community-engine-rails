# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::MerchantAccount do
  subject(:merchant_account) { build('better_together/billing/merchant_account') }

  around do |example|
    original = ENV.fetch('BT_BILLING_MERCHANT_ONBOARDING_ENABLED', nil)
    ENV['BT_BILLING_MERCHANT_ONBOARDING_ENABLED'] = 'false'
    example.run
  ensure
    ENV['BT_BILLING_MERCHANT_ONBOARDING_ENABLED'] = original
  end

  it 'is valid with the factory defaults' do
    expect(merchant_account).to be_valid
  end

  it 'requires a supported provider' do
    merchant_account.provider = 'square'

    expect(merchant_account).not_to be_valid
    expect(merchant_account.errors[:provider]).to be_present
  end

  it 'defaults onboarding to disabled' do
    expect(described_class.onboarding_enabled?).to be(false)
    expect(merchant_account.onboarding_enabled?).to be(false)
  end

  it 'can belong to a person' do
    merchant_account = build('better_together/billing/merchant_account', :person_owned)

    expect(merchant_account).to be_valid
    expect(merchant_account.owner).to be_a(BetterTogether::Person)
  end

  it 'reports merchant readiness from status and capabilities' do
    merchant_account.status = 'active'
    merchant_account.charges_enabled = true
    merchant_account.payouts_enabled = true

    expect(merchant_account.merchant_ready?).to be(true)
  end

  it 'identifies onboarding-incomplete states' do
    merchant_account.status = 'required_action'

    expect(merchant_account.onboarding_incomplete?).to be(true)
  end

  it 'surfaces support attention for disconnected accounts' do
    merchant_account.status = 'disconnected'
    merchant_account.metadata = { 'deauthorized_at' => '2026-05-09T12:00:00Z' }

    expect(merchant_account.support_state).to eq(:disconnected)
    expect(merchant_account.support_attention_needed?).to be(true)
    expect(merchant_account.deauthorized_at).to be_present
  end
end
