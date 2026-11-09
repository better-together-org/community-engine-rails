# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Pays a renewal invoice from the payer's store credit, when the credit covers it whole. If not, the
      # invoice waits and the payer is told once a day (the daily sweep tries again, so topping up credit is
      # enough). Returns whether it was paid.
      #
      class PayWithCredit # rubocop:disable Naming/PredicateMethod
        def self.call(...) = new(...).call

        def initialize(period:)
          @period = period
        end

        def call
          order = period.order
          return false unless order&.open? && order.payments.none?
          return hold('store credit is not switched on') unless Configuration.context_for(order.platform, 'store_credit')

          # A savepoint, so an attempt that is refused part-way leaves no half-made payment behind.
          Order.transaction(requires_new: true) { Credit::PayOrder.call(order:) }
          true
        rescue Credit::Refused
          Notifications.deliver('renewal_credit_insufficient', subject: period, dedupe_key: "credit-short:#{period.id}:#{Date.current}")
          false
        end

        private

        attr_reader :period

        def hold(reason) # rubocop:disable Naming/PredicateMethod
          period.update!(status: 'blocked', blocked_reason: reason)
          false
        end
      end
    end
  end
end
