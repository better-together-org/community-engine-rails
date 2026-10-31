# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Lets go of an order that will not be paid: cancels the payments still waiting, closes the
      # offline payments that were waiting for the seller (`expired` when the hold ran out,
      # `cancelled` otherwise), and gives back what the order held while it waited.
      class Release
        def self.call(order, outcome: 'cancelled')
          order.payments.pending.find_each { |payment| payment.update!(status: 'cancelled') }
          order.offline_payments.waiting.find_each { |offline| OfflinePayments::Transition.release(offline, outcome) }
          order.lines.each { |line| line.purchasable.release!(quantity: line.quantity) }
        end
      end
    end
  end
end
