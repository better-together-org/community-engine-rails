# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Cancels an order nobody has paid for, cancels what was waiting to be paid, and gives back
      # what the order held. An order that has money against it cannot be cancelled: it is
      # refunded instead. Neither can one with a cheque the seller has received and not yet seen clear.
      class Cancel
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order)
          @order = order
        end

        def call
          order.with_lock do
            raise Refused, 'only an unpaid order can be cancelled' unless cancellable?

            Release.call(order)
            order.update!(status: 'cancelled', cancelled_at: Time.current)
            Notifications.deliver('order_cancelled', subject: order)
          end
          order
        end

        private

        attr_reader :order

        def cancellable?
          order.can_become?('cancelled') && order.payments.where(status: %w[succeeded partially_refunded refunded]).none? &&
            order.offline_payments.received.none?
        end
      end
    end
  end
end
