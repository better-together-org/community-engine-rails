# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # What a placed order does about payment, by the way of paying it was placed with (a PaymentChoice):
      #
      # * a method the seller confirms by hand (cash, a cheque, an e-transfer) opens an offline payment that
      #   waits for the seller to say the money arrived;
      # * store credit is spent now and pays the order whole (see Credit::PayOrder), or the order is refused;
      # * a method through a processor starts a pending payment the buyer completes at the processor (see
      #   Checkout::Start).
      #
      # Nothing is opened for an order that costs nothing, or placed with no method named.
      class OpenPayment
        def self.call(...) = new(...).call

        def initialize(order:, choice:, seller_assisted: false)
          @order = order
          @choice = choice
          @seller_assisted = seller_assisted
        end

        def call
          return unless order.total_cents.positive?

          if choice.offline_setting then open_offline
          elsif choice.credit_setting then pay_with_credit
          elsif choice.processor_adapter then open_processor_payment
          end
        end

        private

        attr_reader :order, :choice, :seller_assisted

        def open_offline = OfflinePayments::Open.call(order:, setting: choice.offline_setting, seller_assisted:)

        def pay_with_credit
          Credit::PayOrder.call(order:)
        rescue Credit::Refused => e
          raise Place::Refused, e.message
        end

        def open_processor_payment
          Payments::Create.call(order:, processor: order_processor, amount_cents: order.balance_cents, idempotency_key: "checkout:#{order.id}:1")
        end

        def order_processor = choice.processor_adapter.processor_name.to_s
      end
    end
  end
end
