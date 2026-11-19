# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Pays all or part of an order from its buyer's store credit.
      #
      # Credit is one way of paying among others and can be a part of a payment: it spends what is asked (the
      # whole balance by default), and never more than the buyer can spend, so "use all my credit and pay the
      # rest another way" is the same call with no amount. It makes the payment, spends the credit against it,
      # and marks it paid, which settles the order (partly paid, or paid if that completes it).
      #
      # Everything happens in the caller's transaction, so if the credit does not cover what was asked for
      # nothing is left behind. Repeating a request with the same key returns the payment already made.
      class PayOrder
        def self.call(...) = new(...).call

        def initialize(order:, amount_cents: nil, idempotency_key: nil)
          @order = order
          @requested = amount_cents
          @key = idempotency_key || "credit:#{order.id}"
        end

        # The succeeded payment.
        def call
          raise Refused, 'store credit pays only for what the platform sells' if order.seller.present?

          existing = order.payments.find_by(idempotency_key: key)
          return existing if existing

          payment = start_payment
          spend(payment)
          Payments::Succeed.call(payment)
        end

        private

        attr_reader :order, :requested, :key

        def start_payment
          Payments::Create.call(order:, processor: 'store_credit', amount_cents: amount, idempotency_key: key)
        rescue Payments::Create::Refused => e
          raise Refused, e.message
        end

        # What was asked, or the balance; never more than the buyer can spend on this kind of purchase.
        def amount
          @amount ||= begin
            wanted = requested || order.balance_cents
            raise Refused, 'there is not enough credit' if requested && requested > usable
            raise Refused, 'there is no credit to spend' unless usable.positive?

            [wanted, usable].min
          end
        end

        def usable = @usable ||= account&.usable_cents(purpose: order.purpose).to_i

        def spend(payment)
          Spend.call(account:, amount_cents: payment.amount_cents, purpose: order.purpose, source: payment,
                     idempotency_key: "spend:#{payment.id}")
        end

        def account
          @account ||= Credit.find_account(platform: order.platform, holder: order.buyer, currency: order.currency)
        end
      end
    end
  end
end
