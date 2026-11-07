# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Adds one part of a payment to an order. Every way of paying can be a part: store credit, cash, a cheque,
      # an e-transfer, a processor. One or several parts complete an order, in any order, now or later; an order
      # that is partly paid is a normal state.
      #
      #   Orders::AddPayment.call(order:, payment_method: 'store_credit', idempotency_key: token)           # what credit can cover
      #   Orders::AddPayment.call(order:, payment_method: 'cash', amount_cents: 2500, idempotency_key: t2)  # a part
      #
      # With no amount it is "the rest": the whole balance, or, for store credit, as much of it as the buyer can
      # spend. An explicit amount can never pass the balance or, for credit, what the buyer can spend.
      #
      # * Whether the method can be used is decided by PaymentChoice, the same rules as placing the order (switched
      #   on for the seller and the kind of purchase, in the order's currency, credit only for what the platform
      #   sells, a processor with a context).
      # * If waiting parts leave too little of the balance, the newest give way (see MakeRoom).
      # * Credit is spent and the payment succeeds at once; a manual method opens an offline payment for the
      #   seller to confirm; a processor method starts a pending payment the buyer completes at the processor.
      #
      # Repeating a request with the same `idempotency_key` returns the payment it already made.
      class AddPayment
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, payment_method:, idempotency_key:, amount_cents: nil, seller_assisted: false) # rubocop:disable Metrics/ParameterLists
          @order = order
          @name = payment_method.to_s
          @requested = amount_cents
          @key = idempotency_key.to_s
          @seller_assisted = seller_assisted
        end

        # The payment made.
        def call
          raise Refused, 'a part needs a key' if key.blank?

          order.with_lock do
            existing = order.payments.find_by(idempotency_key: part_key)
            next existing if existing

            check!
            take_part
          end
        rescue Credit::Refused, MakeRoom::Refused, Payments::Create::Refused => e
          raise Refused, e.message
        end

        private

        attr_reader :order, :name, :requested, :key, :seller_assisted

        def part_key = "part:#{order.id}:#{key}"

        def choice
          @choice ||= PaymentChoice.new(platform: order.platform, seller: order.seller, name:, purpose: order.purpose, currency: order.currency)
        end

        def check!
          raise Refused, 'that order is not waiting for payment' unless order.open? || order.expired?
          raise Refused, 'there is nothing left to pay' unless order.balance_cents.positive?

          check_method!
          check_amount!
        end

        def check_method!
          raise Refused, 'that is not a way of paying' unless choice.known?

          problem = choice.problem
          raise Refused, problem if problem
        end

        def check_amount!
          return if requested.nil?

          raise Refused, 'a part must be more than nothing' unless requested.positive?
          raise Refused, 'that is more than is left to pay' if requested > order.balance_cents
        end

        def take_part
          return pay_with_credit if choice.credit_setting

          amount = requested || order.balance_cents
          MakeRoom.call(order:, amount_cents: amount)
          choice.offline_setting ? open_offline(amount) : open_processor(amount)
        end

        # Credit makes its own room: it spends now, so what it takes is counted against the balance at once.
        def pay_with_credit
          amount = [requested || order.balance_cents, usable_credit].min
          MakeRoom.call(order:, amount_cents: amount)
          Credit::PayOrder.call(order:, amount_cents: requested || amount, idempotency_key: part_key)
        end

        def usable_credit
          Credit.usable_cents(platform: order.platform, holder: order.buyer, currency: order.currency, purpose: order.purpose)
        end

        def open_offline(amount)
          OfflinePayments::Open.call(order:, setting: choice.offline_setting, seller_assisted:, amount_cents: amount,
                                     idempotency_key: part_key).payment
        end

        def open_processor(amount)
          raise Refused, 'that way of paying is not available' unless choice.processor_adapter

          Payments::Create.call(order:, processor: name, amount_cents: amount, idempotency_key: part_key)
        end
      end
    end
  end
end
