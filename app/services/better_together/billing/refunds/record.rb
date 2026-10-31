# frozen_string_literal: true

module BetterTogether
  module Billing
    module Refunds
      # Records money given back against a payment, then settles the order. For cash, a cheque or
      # an e-transfer the seller says they handed it back (`recorded`); for a vendor processor the
      # refund is made there and recorded as `succeeded`.
      #
      # Repeating the same request (same idempotency key) returns the refund it already made.
      class Record
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(payment:, amount_cents:, idempotency_key:, status: 'recorded', reason: nil, recorded_by: nil, # rubocop:disable Metrics/ParameterLists
                       processor_reference: nil, notify: true)
          @payment = payment
          @amount_cents = amount_cents
          @idempotency_key = idempotency_key.to_s
          @status = status
          @reason = reason
          @recorded_by = recorded_by
          @processor_reference = processor_reference
          @notify = notify
        end

        def call
          payment.with_lock do
            existing = payment.refunds.find_by(idempotency_key:)
            next existing if existing

            refund = payment.refunds.create!(refund_attributes)
            settle(refund)
            refund
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :payment, :amount_cents, :idempotency_key, :status, :reason, :recorded_by, :processor_reference, :notify

        def refund_attributes
          { platform_id: payment.platform_id, amount_cents:, currency: payment.currency, idempotency_key:, status:, reason:,
            recorded_by:, processor_reference: }
        end

        # The payment is refunded in part or in full, then so is its order.
        def settle(refund)
          payment.reload
          payment.update!(status: payment.refundable_cents.zero? ? 'refunded' : 'partially_refunded')
          Orders::Settle.call(payment.order)
          return unless notify

          Notifications.deliver(refund.status == 'recorded' ? 'refund_recorded' : 'refund_issued', subject: refund, actor: recorded_by)
        end
      end
    end
  end
end
