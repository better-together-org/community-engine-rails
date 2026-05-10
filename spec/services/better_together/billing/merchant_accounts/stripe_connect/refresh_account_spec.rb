# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount do
  subject(:service) { described_class.new }

  it 'delegates refreshes through the sync service' do
    merchant_account = build_stubbed('better_together/billing/merchant_account')
    sync_service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount, call: :ok)

    allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount).to receive(:new).and_return(sync_service)

    result = service.call(merchant_account:)

    expect(result).to eq(:ok)
    expect(sync_service).to have_received(:call).with(
      merchant_account:,
      owner: nil,
      stripe_account_id: merchant_account.external_account_id
    )
  end

  it 'can refresh using an owner when no local merchant projection exists yet' do
    owner = build_stubbed(:better_together_person)
    sync_service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount, call: :ok)

    allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount).to receive(:new).and_return(sync_service)

    result = service.call(owner:)

    expect(result).to eq(:ok)
    expect(sync_service).to have_received(:call).with(
      merchant_account: nil,
      owner:,
      stripe_account_id: nil
    )
  end
end
