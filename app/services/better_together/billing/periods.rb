# frozen_string_literal: true

module BetterTogether
  module Billing
    # Where each billing period of a plan starts and ends.
    #
    # Every period is counted from one **anchor** (the moment the subscription began), never from the
    # period before it, so a subscription that began on January 31 renews on February 28 (or 29), then
    # March 31, not the 28th from then on: Rails clamps a day that does not exist, and the next period is
    # worked out from the anchor again. The sums are done in the platform's time zone, so a renewal at
    # 9 a.m. stays at 9 a.m. across a daylight saving change; the times are stored in UTC.
    #
    #   Periods.starts_at(anchor:, plan:, sequence: 3, time_zone: platform.time_zone)
    module Periods
      module_function

      # Whole months in one period of the plan.
      def months(plan) = plan.interval_count * (plan.billing_interval == 'year' ? 12 : 1)

      # When period `sequence` begins. `anchor_sequence` is the period the anchor itself begins (0 unless
      # a subscription was started again after lapsing; see Subscriptions::OrderPaid).
      def starts_at(anchor:, plan:, sequence:, time_zone: 'UTC', anchor_sequence: 0)
        raise ArgumentError, 'a plan that does not renew has no periods' unless plan.recurring?

        anchor.in_time_zone(time_zone).advance(months: months(plan) * (sequence - anchor_sequence)).utc
      end

      # When period `sequence` ends, which is when the next begins.
      def ends_at(anchor:, plan:, sequence:, time_zone: 'UTC', anchor_sequence: 0)
        starts_at(anchor:, plan:, sequence: sequence + 1, time_zone:, anchor_sequence:)
      end
    end
  end
end
