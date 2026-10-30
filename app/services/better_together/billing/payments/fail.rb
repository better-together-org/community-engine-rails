# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Marks a payment as failed. The order stays open, so the buyer can try another way.
      class Fail
        def self.call(payment)
          payment.with_lock { payment.update!(status: 'failed', failed_at: Time.current) if payment.pending? }
          payment
        end
      end
    end
  end
end
