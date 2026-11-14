# frozen_string_literal: true

module BetterTogether
  module Billing
    module Refunds
      # Records money given back against a payment, then settles the order. For cash, a cheque or
      # an e-transfer the seller says they handed it back (`recorded`); for a vendor processor the
      # refund is made there and recorded as `succeeded`. A payment made with store credit is refunded
      # to the buyer's credit, in the same transaction, and is `succeeded` at once (see Credit::Reverse).
      #
      # Repeating the same request (same idempotency key) returns the refund it already made. So does a
      # refund with the same processor reference: core asking the processor for a refund and the
      # processor then reporting that refund are one refund, not two.
      #
      # The tax inside a refund is pro-rated from the order's tax (never worked out again from today's rates):
      # the refund's share of the order total. The refund that brings the order to fully refunded takes whatever
      # tax is left, so the shares add up to the order's tax to the cent.
      class Record
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(payment:, amount_cents:, idempotency_key:, status: nil, reason: nil, recorded_by: nil, # rubocop:disable Metrics/ParameterLists
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
          DeadlockRetry.run { record }
        end

        private

        def record
          payment.with_lock do
            existing = already_recorded
            next existing if existing

            refund = payment.refunds.create!(refund_attributes)
            give_back_credit(refund)
            settle(refund)
            refund
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        attr_reader :payment, :amount_cents, :idempotency_key, :status, :reason, :recorded_by, :processor_reference, :notify

        def already_recorded
          found = payment.refunds.find_by(idempotency_key:)
          found || (payment.refunds.find_by(processor_reference:) if processor_reference.present?)
        end

        def refund_attributes
          { platform_id: payment.platform_id, amount_cents:, currency: payment.currency, idempotency_key:, status: resolved_status, reason:,
            recorded_by:, processor_reference:, tax_cents: ProRatedTax.new(payment:, amount_cents:).cents }
        end

        # Credit goes back at once; money the seller hands back is recorded; a processor says what it did.
        def resolved_status
          return 'succeeded' if credit_payment?

          status || 'recorded'
        end

        def credit_payment? = Billing.internal_method?(payment.processor)

        def give_back_credit(refund)
          return unless credit_payment?

          Credit::Reverse.call(payment:, amount_cents:, idempotency_key: "reverse:#{refund.id}", refund:, actor: recorded_by)
        rescue Credit::Refused => e
          raise Refused, e.message
        end

        # The payment is refunded in part or in full, then so is its order.
        def settle(refund)
          payment.reload.refresh_refund_status!
          LocalSettlement.sync_refunds!(payment)
          Orders::Settle.call(payment.order)
          return unless notify

          Notifications.deliver(refund.status == 'recorded' ? 'refund_recorded' : 'refund_issued', subject: refund, actor: recorded_by)
        end
      end
    end
  end
end
