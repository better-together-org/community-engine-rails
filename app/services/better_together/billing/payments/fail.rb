# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Marks a payment as failed. The order stays open, so the buyer can try another way.
      # `failure_code` is a short processor-neutral reason (`declined`, `expired`, `action_required`)
      # kept on the payment; never raw processor text.
      class Fail
        def self.call(payment, failure_code: nil)
          payment.with_lock do
            payment.update!(status: 'failed', failed_at: Time.current, failure_code:) if payment.in_flight?
          end
          payment
        end
      end
    end
  end
end
