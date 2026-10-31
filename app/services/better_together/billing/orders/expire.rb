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
          order.with_lock do
            next false unless order.hold_expired? && order.can_become?('expired')

            Release.call(order)
            order.update!(status: 'expired')
            Notifications.deliver('order_expired', subject: order)
            true
          end
        end

        private

        attr_reader :order
      end
    end
  end
end
