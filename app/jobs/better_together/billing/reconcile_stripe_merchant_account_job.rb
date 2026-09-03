# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconciles Stripe Connect status for a single merchant account.
    class ReconcileStripeMerchantAccountJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(merchant_account_id)
        merchant_account = BetterTogether::Billing::MerchantAccount.find_by(id: merchant_account_id, provider: 'stripe_connect')
        return unless merchant_account

        BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount.new.call(merchant_account:)
      end
    end
  end
end
