# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Lets an order that was not paid in time lapse, cancelling what was waiting and giving back
      # what it held. A payment confirmed later can still pay it (see Settle); expiring is not
      # the same as cancelling.
      class Expire
        def self.call(order) = new(order).call

        def initialize(order)
          @order = order
        end

        # Returns true when the order lapsed, false when it was left alone (paid meanwhile, not
        # yet due, or not waiting for payment).
        def call
          DeadlockRetry.run { expire }
        end

        private

        def expire
          order.with_lock do
            next false unless order.hold_expired? && order.can_become?('expired')
            next false if money_in_flight?

            Release.call(order, outcome: 'expired')
            order.update!(status: 'expired')
            Notifications.deliver('order_expired', subject: order)
            true
          end
        end

        attr_reader :order

        # A cheque the seller has received but not yet seen clear, or a payment the processor has in
        # flight (a bank debit), keeps the order open.
        def money_in_flight? = order.offline_payments.received.exists? || order.payments.processing.exists?
      end
    end
  end
end
