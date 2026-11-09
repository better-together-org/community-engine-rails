# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Pays an order from its buyer's store credit, all of it. Credit only ever pays an order in full:
      # a part-payment would leave an order half paid that must be unwound if it is cancelled or lapses.
      #
      # It makes the payment, spends the credit against it, and marks it paid, which settles the order.
      # Everything happens in the caller's transaction, so if the credit does not cover the order nothing
      # is left behind.
      class PayOrder
        def self.call(...) = new(...).call

        def initialize(order:)
          @order = order
        end

        # The succeeded payment.
        def call
          raise Refused, 'store credit pays only for what the platform sells' if order.seller.present?

          payment = start_payment
          spend(payment)
          Payments::Succeed.call(payment)
        end

        private

        attr_reader :order

        def start_payment
          Payments::Create.call(order:, processor: 'store_credit', amount_cents: order.balance_cents, idempotency_key: "credit:#{order.id}")
        rescue Payments::Create::Refused => e
          raise Refused, e.message
        end

        def spend(payment)
          Spend.call(account:, amount_cents: payment.amount_cents, purpose: order.purpose, source: payment,
                     idempotency_key: "spend:#{payment.id}")
        end

        def account
          Credit.find_account(platform: order.platform, holder: order.buyer, currency: order.currency) ||
            raise(Refused, 'there is no store credit to spend')
        end
      end
    end
  end
end
