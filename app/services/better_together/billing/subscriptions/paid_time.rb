# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # When an order was really paid, for deciding whether it paid in time. A cheque posted in time and
      # confirmed late still counts: when the seller recorded the day the money arrived, that day (to its end)
      # is the time, otherwise the moment the payment settled.
      module PaidTime
        module_function

        def for(order)
          offline = order.offline_payments.first
          return offline.received_on.in_time_zone(order.platform.time_zone.presence || 'UTC').end_of_day if offline&.received_on

          order.paid_at || Time.current
        end
      end
    end
  end
end
