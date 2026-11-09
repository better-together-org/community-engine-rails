# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Lets go of an order that will not be paid: cancels the payments still waiting, and gives back
      # what the order held while it waited.
      class Release
        def self.call(order)
          order.payments.pending.find_each { |payment| payment.update!(status: 'cancelled') }
          order.line_items.each { |line_item| line_item.purchasable.release!(quantity: line_item.quantity) }
        end
      end
    end
  end
end
