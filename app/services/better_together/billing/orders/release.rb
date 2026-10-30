# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Gives back what an order held while it waited to be paid.
      class Release
        def self.call(order) = order.lines.each { |line| line.purchasable.release!(quantity: line.quantity) }
      end
    end
  end
end
