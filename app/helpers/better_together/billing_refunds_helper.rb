# frozen_string_literal: true

module BetterTogether
  # What an order shows about money given back. Failed refunds never moved money, so they are not listed.
  module BillingRefundsHelper
    def billing_order_refunds(order)
      BetterTogether::Billing::Refund.where(payment_id: order.payments.select(:id), status: BetterTogether::Billing::Refund::COUNTED)
                                     .order(:created_at, :id)
    end

    def billing_refund_status_label(refund)
      t("better_together.billing.orders.refund_status_#{refund.status}")
    end
  end
end
