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
    expect(sync_service).to have_received(:call).with(merchant_account:)
  end
end
