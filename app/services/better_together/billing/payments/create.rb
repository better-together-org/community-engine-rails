# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Starts a payment against an order. Repeating the same request (same idempotency key)
      # returns the payment it already made instead of making a second one.
      class Create
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, processor:, amount_cents:, idempotency_key:)
          @order = order
          @processor = processor.to_s
          @amount_cents = amount_cents
          @idempotency_key = idempotency_key.to_s
        end

        def call
          order.payments.find_by(idempotency_key:) || start
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        def start
          check_payable!
          order.payments.create!(platform_id: order.platform_id, processor:, amount_cents:, currency: order.currency, idempotency_key:)
        end

        def check_payable!
          raise Refused, 'that order is not waiting for payment' unless order.open? || order.expired?
          raise Refused, 'that is more than is owed' if amount_cents > order.balance_cents - pending_cents
        end

        attr_reader :order, :processor, :amount_cents, :idempotency_key

        # What other payments in flight already cover, so two parts cannot add up to more than owed.
        def pending_cents = order.payments.pending.sum(:amount_cents)
      end
    end
  end
end
