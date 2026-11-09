# frozen_string_literal: true

module BetterTogether
  module Billing
    # Store credit: a balance a person holds with a platform, kept as a ledger.
    #
    # Every change goes through one of the services in this namespace, under the account's lock, and
    # leaves entries behind; the account's balance is a cache of its lots and is never written by hand.
    #
    #   Grant      a steward gives credit (never to themselves)
    #   Spend      pays for an order, soonest-expiring credit first
    #   Reverse    gives back credit spent on a payment that is refunded
    #   ExpireLots lets credit past its date go
    #   Recalculate checks the cache against the lots and entries
    #
    # See docs/billing/store_credit.md.
    module Credit
      class Error < StandardError; end
      # The account cannot cover the amount (or the request is not allowed).
      class Refused < Error; end

      # A refund of credit that cannot go back where it came from (the lot has expired) is credited as
      # new credit that lasts this long, so a refund never extends a promotion.
      REFUND_LOT_DAYS = 30

      module_function

      # The account for a holder on a platform in a currency, made if it does not exist yet.
      def account_for(platform:, holder:, currency:)
        scope = platform.billing_credit_accounts
        scope.find_by(holder:, currency:) || scope.create!(holder:, currency:)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        scope.find_by!(holder:, currency:)
      end

      # The account if there is one; nothing is made by looking.
      def find_account(platform:, holder:, currency:)
        return if platform.nil? || holder.nil?

        platform.billing_credit_accounts.find_by(holder:, currency:)
      end

      # What `holder` could spend now on a purchase of this kind.
      def usable_cents(platform:, holder:, currency:, purpose: nil)
        find_account(platform:, holder:, currency:)&.usable_cents(purpose:).to_i
      end

      # Whether the keyed operation already ran; its entries are the answer.
      def entries_for(account, transaction_key)
        account.entries.where(transaction_key:).to_a
      end

      # Writes one entry and moves the lot and the account to match. The caller holds the account lock.
      def post!(account:, lot:, kind:, amount_cents:, transaction_key:, **attrs) # rubocop:disable Metrics/ParameterLists
        lot.update!(remaining_cents: lot.remaining_cents + amount_cents) unless kind == 'grant'
        account.update!(balance_cents: account.balance_cents + amount_cents)
        account.entries.create!(platform_id: account.platform_id, lot:, kind:, amount_cents:, transaction_key:,
                                balance_after_cents: account.balance_cents, **attrs)
      end
    end
  end
end
