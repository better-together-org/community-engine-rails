# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount do
  subject(:service) { described_class.new }

  let(:owner) { create(:better_together_community) }
  let(:requirements) do
    double(
      currently_due: currently_due,
      eventually_due: [],
      past_due: [],
      pending_verification: [],
      disabled_reason: nil
    )
  end
  let(:currently_due) { [] }
  let(:stripe_account) do
    instance_double(
      Stripe::Account,
      id: 'acct_sync_123',
      country: 'CA',
      default_currency: 'cad',
      charges_enabled: charges_enabled,
      payouts_enabled: payouts_enabled,
      details_submitted: details_submitted,
      business_type: 'company',
      capabilities: { transfers: 'active', card_payments: 'active' },
      requirements:
    )
  end
  let(:charges_enabled) { true }
  let(:payouts_enabled) { true }
  let(:details_submitted) { true }

  it 'creates and syncs a merchant account from a Stripe account object' do
    result = service.call(owner:, stripe_account:)

    expect(result.created).to be(true)
    expect(result.merchant_account).to be_persisted
    expect(result.merchant_account.owner).to eq(owner)
    expect(result.merchant_account.provider).to eq('stripe_connect')
    expect(result.merchant_account.status).to eq('active')
    expect(result.merchant_account.charges_enabled).to be(true)
    expect(result.merchant_account.payouts_enabled).to be(true)
    expect(result.merchant_account.capabilities).to eq(
      'transfers' => 'active',
      'card_payments' => 'active'
    )
    expect(result.merchant_account.currency).to eq('CAD')
  end

  it 'maps immediately-due requirements to required_action' do
    currently_due << 'external_account'
    allow(stripe_account).to receive(:charges_enabled).and_return(false)

    result = service.call(owner:, stripe_account:)

    expect(result.merchant_account.status).to eq('required_action')
  end

  it 'keeps fully enabled accounts active when only eventually_due requirements remain' do
    allow(requirements).to receive(:eventually_due).and_return(['owners.address'])

    result = service.call(owner:, stripe_account:)

    expect(result.merchant_account.status).to eq('active')
  end

  it 'refreshes an existing account by stripe account id' do
    merchant_account = create(
      'better_together/billing/merchant_account',
      owner:,
      provider: 'stripe_connect',
      external_account_id: 'acct_sync_123',
      status: 'pending',
      charges_enabled: false,
      payouts_enabled: false
    )
    allow(Stripe::Account).to receive(:retrieve).with('acct_sync_123').and_return(stripe_account)

    result = service.call(merchant_account:)

    expect(result.created).to be(false)
    expect(result.merchant_account).to eq(merchant_account)
    expect(result.merchant_account.reload.status).to eq('active')
  end

  it 'syncs the Pay merchant processor for the owner' do
    result = service.call(owner:, stripe_account:)

    expect(owner.reload.merchant_processor).to be_present
    expect(owner.merchant_processor.processor).to eq('stripe')
    expect(owner.merchant_processor.processor_id).to eq('acct_sync_123')
    expect(result.merchant_account.external_account_id).to eq('acct_sync_123')
  end
end
