# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Gives credit back after a payment made with it is refunded, as much as `amount_cents` and never
      # more than was spent and not yet given back.
      #
      # Credit goes back to the lot it was taken from while that lot is still valid. A lot that has
      # expired meanwhile is not revived: that part comes back as a new refund lot that lasts
      # REFUND_LOT_DAYS, so a refund never extends a promotion.
      #
      # Repeating a request with the same `idempotency_key` returns the entries it already made.
      class Reverse
        def self.call(...) = new(...).call

        def initialize(payment:, amount_cents:, idempotency_key:, refund: nil, actor: nil, now: Time.current) # rubocop:disable Metrics/ParameterLists
          @payment = payment
          @amount_cents = amount_cents.to_i
          @idempotency_key = idempotency_key.to_s
          @refund = refund
          @actor = actor
          @now = now
        end

        # The entries written.
        def call
          raise Refused, 'a reversal must be more than nothing' unless amount_cents.positive?

          account.with_lock do
            existing = Credit.entries_for(account, idempotency_key)
            next existing if existing.any?

            reverse
          end
        end

        private

        attr_reader :payment, :amount_cents, :idempotency_key, :refund, :actor, :now

        # The account the payment's credit was taken from.
        def account
          @account ||= spends.first&.account || raise(Refused, 'no credit was spent on that payment')
        end

        def spends
          @spends ||= CreditEntry.spends.where(platform_id: payment.platform_id, source: payment)
                                 .includes(:account, :lot).order(:created_at, :id).to_a
        end

        def reverse
          left = amount_cents
          entries = []
          spends.each do |spend|
            take = [restorable(spend), left].min
            next unless take.positive?

            left -= take
            entries << restore(spend, take)
          end
          raise Refused, 'more than was spent on that payment' if left.positive?

          entries
        end

        # What of that spend has not been given back yet.
        def restorable(spend)
          given_back = CreditEntry.where(platform_id: spend.platform_id, reverses_entry_id: spend.id).sum(:amount_cents)
          -spend.amount_cents - given_back
        end

        def restore(spend, take)
          lot = spend.lot
          lot = refund_lot(take) if lot.expired?(now)
          lot.lock!
          Credit.post!(account:, lot:, kind: 'spend_reversal', amount_cents: take, transaction_key: idempotency_key,
                       reverses_entry: spend, source: refund, actor:)
        end

        # A new lot that already holds the amount; post! adds it to the lot, so it starts empty.
        def refund_lot(amount)
          account.lots.create!(platform_id: account.platform_id, origin: 'refund', amount_cents: amount, remaining_cents: 0,
                               expires_at: now + REFUND_LOT_DAYS.days, granted_by: actor)
        end
      end
    end
  end
end
