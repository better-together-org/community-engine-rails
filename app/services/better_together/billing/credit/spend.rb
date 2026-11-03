# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Spends credit on a payment, taking the lot that expires soonest first (then the oldest). One entry
      # is written for each lot touched. All of it or none: if the unexpired credit that may pay for this
      # kind of purchase does not cover the amount, nothing is spent.
      #
      # Repeating a request with the same `idempotency_key` returns the entries it already made.
      class Spend
        def self.call(...) = new(...).call

        def initialize(account:, amount_cents:, purpose:, source:, idempotency_key:, now: Time.current) # rubocop:disable Metrics/ParameterLists
          @account = account
          @amount_cents = amount_cents.to_i
          @purpose = purpose.to_s
          @source = source
          @idempotency_key = idempotency_key.to_s
          @now = now
        end

        # The entries written, one per lot.
        def call
          raise Refused, 'a spend must be more than nothing' unless amount_cents.positive?

          account.with_lock do
            existing = Credit.entries_for(account, idempotency_key)
            next existing if existing.any?

            spend
          end
        end

        private

        attr_reader :account, :amount_cents, :purpose, :source, :idempotency_key, :now

        def spend
          left = amount_cents
          entries = lots.map do |lot|
            take = [lot.remaining_cents, left].min
            left -= take
            Credit.post!(account:, lot:, kind: 'spend', amount_cents: -take, transaction_key: idempotency_key, source:)
          end
          raise Refused, 'there is not enough credit' if left.positive?

          entries
        end

        # Only as many lots as are needed, soonest-expiring first. The account lock keeps anyone else out.
        def lots
          covered = 0
          account.lots.usable(purpose:, now:).soonest_expiring.take_while do |lot|
            (covered < amount_cents).tap { covered += lot.remaining_cents }
          end
        end
      end
    end
  end
end
