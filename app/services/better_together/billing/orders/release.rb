# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Gives back what an order held while it waited to be paid.
      class Release
        def self.call(order) = order.line_items.each { |line_item| line_item.purchasable.release!(quantity: line_item.quantity) }
      end
    end
  end
end
