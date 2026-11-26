# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Pays a renewal invoice from the payer's store credit, as much as the credit covers. Credit is one way of paying
      # among others, so when it covers only part the invoice is left partly paid (it stays open, and the payer can pay
      # the rest any way they like from the invoice) and the payer is told once a day. The daily sweep tries again, so
      # topping up credit is enough. Returns whether the invoice was paid in full.
      #
      # It never touches a part the payer added themselves: it spends only what the parts already waiting leave free.
      class PayWithCredit # rubocop:disable Naming/PredicateMethod
        def self.call(...) = new(...).call

        def initialize(period:)
          @period = period
        end

        def call
          return false unless order&.open? && free_cents.positive?
          return hold('store credit is not switched on') unless Configuration.context_for(order.platform, 'store_credit')

          spend if usable_cents.positive?
          order.reload.paid? || short
        end

        private

        attr_reader :period

        def order = period.order

        # What is still to pay and not already spoken for by a part waiting to be completed.
        def free_cents = order.balance_cents - order.payments.in_flight.sum(:amount_cents)

        def usable_cents
          Credit.usable_cents(platform: order.platform, holder: order.buyer, currency: order.currency, purpose: order.purpose)
        end

        # A savepoint, so an attempt refused part-way leaves no half-made payment behind.
        def spend
          Order.transaction(requires_new: true) do
            Credit::PayOrder.call(order:, amount_cents: [free_cents, usable_cents].min,
                                  idempotency_key: "renewal:#{order.id}:#{order.payments.count}")
          end
        rescue Credit::Refused
          nil
        end

        def short # rubocop:disable Naming/PredicateMethod
          Notifications.deliver('renewal_credit_insufficient', subject: period, dedupe_key: "credit-short:#{period.id}:#{Date.current}")
          false
        end

        def hold(reason) # rubocop:disable Naming/PredicateMethod
          period.update!(status: 'blocked', blocked_reason: reason)
          false
        end
      end
    end
  end
end
