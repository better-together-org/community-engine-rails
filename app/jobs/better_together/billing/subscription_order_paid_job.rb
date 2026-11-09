# frozen_string_literal: true

module BetterTogether
  module Billing
    # A subscription order was paid: start the subscription it begins, or advance the one it renews. A job, run
    # after the payment is committed, so it can be retried and can never undo a recorded payment. Safe to repeat.
    class SubscriptionOrderPaidJob < ApplicationJob
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      def perform(order)
        Subscriptions::OrderPaid.call(order)
      end
    end
  end
end
