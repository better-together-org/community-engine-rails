# frozen_string_literal: true

module BetterTogether
  module Billing
    # Keeps Pay's records of money in step with a payment Community Engine settles itself (cash, a
    # cheque, an e-transfer, store credit).
    #
    # The pending part of such a payment (waiting for the seller to say the money arrived) lives in
    # Billing::Payment and Billing::OfflinePayment, because Pay has no pending charge. When the money
    # has settled, a Pay::Local::Charge is written for it and linked to the payment, so a payment made
    # this way is a charge like any other to Pay and to everything built on Pay's records, and
    # `payment.refunded_cents == pay_charge.amount_refunded` holds for every payment, local or not.
    # For a payment through a processor the processor is the authority and Pay syncs its own charge:
    # nothing here touches it.
    module LocalSettlement
      module_function

      # Records the settled payment as a Pay charge on the buyer's local customer for the platform.
      # Safe to repeat: a payment that already has its charge is left alone.
      def record!(payment)
        return unless local?(payment) && payment.succeeded? && payment.pay_charge.blank?

        charge = customer_for(payment).charge(
          payment.amount_cents,
          currency: payment.currency.downcase, payment_method_type: payment.processor,
          metadata: { bt_order_id: payment.order_id, bt_payment_id: payment.id, bt_platform_id: payment.platform_id }
        )
        payment.update!(pay_charge: charge)
      end

      # Brings the Pay charge's refunded amount in line with the refunds counted against the payment.
      def sync_refunds!(payment)
        charge = payment.pay_charge
        return unless charge.is_a?(Pay::Local::Charge)

        charge.update!(amount_refunded: payment.refunded_cents)
      end

      def local?(payment) = !payment.remote?

      # The buyer is the customer, on the platform that sold: one local customer per person and platform.
      def customer_for(payment)
        payment.order.buyer.add_payment_processor(:local, platform: payment.platform).api_record
      end
    end
  end
end
