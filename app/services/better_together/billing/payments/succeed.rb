# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Marks a payment as paid and settles its order. Safe to repeat: a payment that already
      # succeeded is returned as it is.
      #
      # `reference` is the processor's id for the charge. Because the processor, not our hold, is the
      # authority on whether money arrived, a reference lets a payment we had already given up on
      # (failed, or cancelled when the order lapsed) succeed after all: a card retried in the same
      # checkout, a session that outlived the hold. Without a reference only an in-flight payment can
      # succeed, so nothing marks money received on a guess.
      #
      # `amount_cents` is what was actually charged (tax can make it more than we asked for), and
      # `pay_charge` links the Pay charge that recorded it.
      #
      # If the order was cancelled meanwhile nobody is owed the money. The payment is recorded (it did
      # arrive), the order is left cancelled, a refund is recorded as pending for the processor to make,
      # and the operators are told.
      class Succeed
        def self.call(...) = new(...).call

        def initialize(payment, reference: nil, amount_cents: nil, pay_charge: nil)
          @payment = payment
          @reference = reference
          @amount_cents = amount_cents
          @pay_charge = pay_charge
        end

        def call
          payment.with_lock { payment.update!(success_attributes) if succeedable? }
          orphan! if payment.orphaned?
          Orders::Settle.call(payment.order)
          payment
        end

        private

        attr_reader :payment, :reference, :amount_cents, :pay_charge

        def succeedable?
          payment.in_flight? || ((payment.failed? || payment.cancelled?) && reference.present?)
        end

        def success_attributes
          { status: 'succeeded', paid_at: Time.current, failure_code: nil,
            processor_reference: reference.presence || payment.processor_reference,
            amount_cents: amount_cents.presence || payment.amount_cents, pay_charge: pay_charge || payment.pay_charge }
        end

        # The refund is recorded once (a fixed key), whatever number of times this runs.
        def orphan!
          Refunds::Record.call(payment:, amount_cents: payment.amount_cents, idempotency_key: "orphan:#{payment.id}", status: 'pending',
                               reason: 'cancelled_order', notify: false)
          Notifications.deliver('payment_orphaned', subject: payment, dedupe_key: "orphan:#{payment.id}")
        rescue Refunds::Record::Refused
          nil # already recorded in full
        end
      end
    end
  end
end
