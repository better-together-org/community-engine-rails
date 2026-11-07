# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Lets an order that was not paid in time lapse, cancelling what was waiting and giving back
      # what it held. A payment confirmed later can still pay it (see Settle); expiring is not
      # the same as cancelling.
      #
      # An order with money against it never lapses on its own: a partly paid order is a normal state, and letting it
      # go would strand what was paid. Only the parts still waiting (a processor session, cash nobody has handed over)
      # are closed; the place stays held, the buyer is told to pay the rest and the steward to decide, and the order
      # stays open until it is paid in full or a steward returns the parts and cancels it.
      class Expire
        def self.call(order) = new(order).call

        def initialize(order)
          @order = order
        end

        # Returns true when the order lapsed, false when it was left alone (paid meanwhile, not
        # yet due, or not waiting for payment).
        def call
          order.with_lock do
            next false unless order.hold_expired?
            next hold_open if order.partly_paid?
            next false unless order.can_become?('expired')
            next false if money_in_flight?

            Release.call(order, outcome: 'expired')
            order.update!(status: 'expired')
            Notifications.deliver('order_expired', subject: order)
            true
          end
        end

        private

        attr_reader :order

        # The unpaid parts end with the hold; the order and its stock stay. Nothing lapsed, so the order is not returned.
        def hold_open
          unpaid_parts.each { |payment| Payments::Cancel.call(payment) }
          order.offline_payments.waiting.find_each { |offline| OfflinePayments::Transition.release(offline, 'expired') }
          Notifications.deliver('order_partial_stalled', subject: order, dedupe_key: "partial-stalled:#{order.id}")
          nil
        end

        # Parts that are still only an intention: not a cheque already received, not a debit the processor is making.
        def unpaid_parts = order.payments.where(status: 'pending').reject { |payment| payment.offline_payment&.money_received? }

        # A cheque the seller has received but not yet seen clear, or a payment the processor has in
        # flight (a bank debit), keeps the order open.
        def money_in_flight? = order.offline_payments.received.exists? || order.payments.processing.exists?
      end
    end
  end
end
