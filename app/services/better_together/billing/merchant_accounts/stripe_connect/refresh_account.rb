# frozen_string_literal: true

module BetterTogether
  module Billing
    module MerchantAccounts
      module StripeConnect
        # Refreshes a stored Stripe Connect merchant account from Stripe.
        class RefreshAccount
          def call(merchant_account: nil, owner: nil)
            BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount.new.call(
              merchant_account:,
              owner:,
              stripe_account_id: merchant_account&.external_account_id || owner&.merchant_processor&.processor_id
            )
          end
        end
      end
    end
  end
end
