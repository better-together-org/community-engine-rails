# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Opens the payment for an order the buyer will pay outside the platform: a pending payment
      # for the whole balance, and an offline payment waiting for the seller to say the money arrived.
      #
      # What the buyer is told about how to pay is copied onto the offline payment now, so a later
      # change to the seller's settings cannot redirect a buyer who is already paying. Repeating the
      # call returns the payment already opened.
      class Open
        def self.call(...) = new(...).call

        def initialize(order:, setting:, seller_assisted: false)
          @order = order
          @setting = setting
          @seller_assisted = seller_assisted
        end

        def call
          payment = Payments::Create.call(order:, processor: setting.processor, amount_cents: order.balance_cents,
                                          idempotency_key: "offline:#{order.id}")
          payment.offline_payment || create_offline_payment(payment)
        end

        private

        attr_reader :order, :setting, :seller_assisted

        def create_offline_payment(payment)
          order.offline_payments.create!(
            platform_id: order.platform_id, payment:, processor: setting.processor, grant_on: setting.grant_on,
            seller_assisted:, expires_at: order.expires_at, instructions_snapshot: setting.instructions
          )
        end
      end
    end
  end
end
