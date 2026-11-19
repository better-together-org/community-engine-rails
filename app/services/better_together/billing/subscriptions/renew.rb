# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A renewal invoice was paid: its period is paid and the Pay subscription moves on to it, using the same
      # columns Pay reads everywhere (`current_period_start`, `current_period_end`, `status`, `ends_at`).
      #
      # * Paid in time, early, or inside the grace: the subscription runs on from the old end. Paying early
      #   moves it on at once; a day of an earlier period is never lost or counted twice.
      # * Paid **after the subscription lapsed** (the grace ran out): nothing is back-dated. The subscription
      #   starts again from the day it was really paid, and its periods are counted from that day on.
      #
      # "In time" is judged by when the money really arrived (a cheque posted in time and confirmed late still
      # counts, see PaidTime). Safe to repeat: a period already paid changes nothing.
      class Renew
        def self.call(...) = new(...).call

        def initialize(term:, order:, paid_at:)
          @term = term
          @order = order
          @paid_at = paid_at
        end

        def call
          term.with_lock do
            period = term.periods.find_by(order_id: order.id)
            next unless period && !period.paid?

            period.update!(status: 'paid', paid_at:)
            move_on(period)
            period
          end
        end

        private

        attr_reader :term, :order, :paid_at

        def subscription = term.pay_subscription

        def move_on(period)
          return if subscription.status == 'canceled' # ended on purpose; the money is a matter for a person (a refund)

          if lapsed_before_payment?
            restart(period)
          else
            subscription.advance!(starts_at: period.starts_at, ends_at: period.ends_at)
            term.update!(grace_ends_at: nil)
          end
        end

        # The grace had already ended when the money arrived.
        def lapsed_before_payment?
          subscription.status == 'unpaid' && term.grace_ends_at.present? && paid_at > term.grace_ends_at
        end

        # Counts from the day it was paid, from this period on.
        def restart(period)
          term.update!(anchor_at: paid_at, anchor_sequence: period.sequence, grace_ends_at: nil)
          subscription.advance!(starts_at: term.period_start(period.sequence), ends_at: term.period_end(period.sequence))
        end
      end
    end
  end
end
