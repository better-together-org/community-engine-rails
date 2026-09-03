# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ReconcileStripeMerchantAccountJob do
  describe '#perform' do
    it 'refreshes a connected Stripe merchant account' do
      merchant_account = create(
        'better_together/billing/merchant_account',
        provider: 'stripe_connect',
        external_account_id: 'acct_job_123'
      )
      refresh_service = instance_double(
        BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount,
        call: true
      )

      allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount).to receive(:new).and_return(refresh_service)

      described_class.perform_now(merchant_account.id)

      expect(refresh_service).to have_received(:call).with(merchant_account:)
    end
  end
end
