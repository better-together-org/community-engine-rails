# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Checks an account's cached balance against its lots and its entries. With `repair: true` the balance
      # is set to what the lots say; the entries are never touched, so a disagreement between the lots and
      # the entries is reported and left for a person to look at.
      class Recalculate
        Result = Data.define(:balance_cents, :lots_cents, :entries_cents) do
          def consistent? = balance_cents == lots_cents && lots_cents == entries_cents
        end

        def self.call(...) = new(...).call

        def initialize(account, repair: false)
          @account = account
          @repair = repair
        end

        def call
          account.with_lock do
            result = measure
            account.update!(balance_cents: result.lots_cents) if repair && result.balance_cents != result.lots_cents
            result
          end
        end

        private

        attr_reader :account, :repair

        def measure
          Result.new(balance_cents: account.balance_cents, lots_cents: account.lots.sum(:remaining_cents),
                     entries_cents: account.entries.sum(:amount_cents))
        end
      end
    end
  end
end
