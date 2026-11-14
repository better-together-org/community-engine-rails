# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Cancels an order with no money against it, cancels what was waiting to be paid, and gives back
      # what the order held. An order that is partly paid is cancelled once each part has been returned
      # (see ReturnPayments): money still held for it is refunded first, not lost with the cancellation. Neither can one
      # with a cheque the seller has received and not yet seen clear.
      class Cancel
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order)
          @order = order
        end

        def call
          DeadlockRetry.run { cancel }
          order
        end

        private

        def cancel
          order.with_lock do
            raise Refused, 'return what was paid before cancelling the order' unless cancellable?

            Release.call(order)
            order.update!(status: 'cancelled', cancelled_at: Time.current)
            Notifications.deliver('order_cancelled', subject: order)
          end
        end

        attr_reader :order

        def cancellable?
          order.can_become?('cancelled') && order.net_paid_cents.zero? && order.offline_payments.received.none?
        end
      end
    end
  end
end
