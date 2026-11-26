# frozen_string_literal: true

module BetterTogether
  module Billing
    # Money paths lock an order, its payments and a credit account, and not always in the same
    # order (a refund starts at the payment, a cancel at the order). Postgres resolves a clash by
    # aborting one transaction, which rolls back whole; running it again is safe. Preferred lock
    # order for new code: order, then payments by id, then the credit account.
    module DeadlockRetry
      ATTEMPTS = 3

      def self.run
        attempts = 0
        begin
          yield
        rescue ActiveRecord::Deadlocked
          attempts += 1
          raise if attempts >= ATTEMPTS

          retry
        end
      end
    end
  end
end
