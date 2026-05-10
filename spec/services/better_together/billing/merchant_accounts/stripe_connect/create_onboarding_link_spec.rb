# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink do
  subject(:service) { described_class.new }

  let(:owner) { create(:better_together_person) }
  let(:requirements) do
    double(
      currently_due: [],
      eventually_due: [],
      past_due: [],
      pending_verification: [],
      disabled_reason: nil
    )
  end
  let(:stripe_account) do
    instance_double(
      Stripe::Account,
      id: 'acct_123',
      country: 'CA',
      default_currency: 'cad',
      charges_enabled: false,
      payouts_enabled: false,
      details_submitted: false,
      business_type: 'individual',
      capabilities: { transfers: 'inactive' },
      requirements:
    )
  end
  let(:account_link) { instance_double(Stripe::AccountLink, url: 'https://connect.stripe.test/onboarding') }

  around do |example|
    original = ENV.fetch('BT_BILLING_MERCHANT_ONBOARDING_ENABLED', nil)
    ENV['BT_BILLING_MERCHANT_ONBOARDING_ENABLED'] = 'true'
    example.run
  ensure
    ENV['BT_BILLING_MERCHANT_ONBOARDING_ENABLED'] = original
  end

  it 'creates a stripe account and onboarding link for a new owner' do
    allow(Stripe::Account).to receive(:create).and_return(stripe_account)
    allow(Stripe::AccountLink).to receive(:create).and_return(account_link)

    result = service.call(
      owner:,
      refresh_url: 'https://example.test/refresh',
      return_url: 'https://example.test/return'
    )

    expect(result.created).to be(true)
    expect(result.url).to eq('https://connect.stripe.test/onboarding')
    expect(result.merchant_account).to be_persisted
    expect(result.merchant_account.provider).to eq('stripe_connect')
    expect(result.merchant_account.external_account_id).to eq('acct_123')
    expect(Stripe::Account).to have_received(:create).with(
      hash_including(
        business_type: 'individual',
        metadata: hash_including(
          bt_owner_type: 'BetterTogether::Person',
          bt_owner_id: owner.id
        )
      )
    )
    expect(Stripe::AccountLink).to have_received(:create).with(
      account: 'acct_123',
      refresh_url: 'https://example.test/refresh',
      return_url: 'https://example.test/return',
      type: 'account_onboarding'
    )
  end

  it 'reuses an existing stripe account id instead of creating a new account' do
    owner.set_merchant_processor(:stripe, processor_id: 'acct_existing')
    merchant_account = create(
      'better_together/billing/merchant_account',
      :person_owned,
      owner:,
      provider: 'stripe_connect',
      external_account_id: 'acct_existing'
    )
    existing_account = instance_double(
      Stripe::Account,
      id: 'acct_existing',
      country: stripe_account.country,
      default_currency: stripe_account.default_currency,
      charges_enabled: stripe_account.charges_enabled,
      payouts_enabled: stripe_account.payouts_enabled,
      details_submitted: stripe_account.details_submitted,
      business_type: stripe_account.business_type,
      capabilities: stripe_account.capabilities,
      requirements: stripe_account.requirements
    )

    allow(Stripe::Account).to receive(:retrieve).with('acct_existing').and_return(existing_account)
    allow(Stripe::Account).to receive(:create)
    allow(Stripe::AccountLink).to receive(:create).and_return(account_link)

    result = service.call(
      owner:,
      refresh_url: 'https://example.test/refresh',
      return_url: 'https://example.test/return'
    )

    expect(result.created).to be(false)
    expect(result.merchant_account).to eq(merchant_account)
    expect(Stripe::Account).not_to have_received(:create)
  end

  it 'creates and stores a Pay merchant processor for the owner' do
    allow(Stripe::Account).to receive(:create).and_return(stripe_account)
    allow(Stripe::AccountLink).to receive(:create).and_return(account_link)

    service.call(
      owner:,
      refresh_url: 'https://example.test/refresh',
      return_url: 'https://example.test/return'
    )

    expect(owner.reload.merchant_processor).to be_present
    expect(owner.merchant_processor.processor).to eq('stripe')
    expect(owner.merchant_processor.processor_id).to eq('acct_123')
  end

  it 'fails closed when onboarding is disabled' do
    ENV['BT_BILLING_MERCHANT_ONBOARDING_ENABLED'] = 'false'

    expect do
      service.call(
        owner:,
        refresh_url: 'https://example.test/refresh',
        return_url: 'https://example.test/return'
      )
    end.to raise_error(described_class::OnboardingDisabledError)
  end
end
