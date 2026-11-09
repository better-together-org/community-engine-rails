# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A steward covers a subscription's next unpaid period without payment (a gift, a hardship, a mistake of
      # ours). The period is `waived`, its invoice is cancelled, and the subscription moves on to it exactly as
      # if it had been paid.
      class Waive
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(term:, by: nil)
          @term = term
          @by = by
        end

        def call
          term.with_lock do
            check!
            period = target_period
            cover(period)
            period
          end
        end

        private

        attr_reader :term, :by

        def subscription = term.pay_subscription

        def check!
          raise Refused, 'that subscription is not renewed by Community Engine' unless term.local?
          raise Refused, 'that subscription has ended' if subscription.status == 'canceled' || subscription.ends_at.present?
        end

        # Covered as if it had been paid: the invoice goes, the subscription moves on.
        def cover(period)
          cancel_order(period.order)
          period.update!(status: 'waived', paid_at: Time.current)
          subscription.advance!(starts_at: period.starts_at, ends_at: period.ends_at)
          term.update!(grace_ends_at: nil)
        end

        def target_period
          term.periods.unsettled.last || term.periods.create!(platform_id: term.platform_id, sequence: next_sequence,
                                                              starts_at: term.period_start(next_sequence),
                                                              ends_at: term.period_end(next_sequence))
        end

        def next_sequence = (term.periods.last&.sequence || -1) + 1

        def cancel_order(order)
          Orders::Cancel.call(order) if order&.open?
        rescue Orders::Cancel::Refused
          nil
        end
      end
    end
  end
end
