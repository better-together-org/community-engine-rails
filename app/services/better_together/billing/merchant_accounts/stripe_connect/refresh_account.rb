# frozen_string_literal: true

module BetterTogether
  module Billing
    module MerchantAccounts
      module StripeConnect
        # Refreshes a stored Stripe Connect merchant account from Stripe.
        class RefreshAccount
          def call(merchant_account:)
            BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount.new.call(
              merchant_account:
            )
          end
        end
      end
    end
  end
end
