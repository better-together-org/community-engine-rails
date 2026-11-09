# frozen_string_literal: true

module BetterTogether
  module Billing
    # The seller records that they gave money back for a payment made outside the platform. The
    # platform cannot move that money, so this only records what the seller says they did, then
    # settles the order. Repeating the same form (a double click) records it once.
    class SaleRefundsController < ApplicationController
      include OwnerScoped

      before_action :set_sale
      after_action :verify_authorized

      def create
        authorize @sale, :refund?
        record_refund(offline_payment)
        redirect_to billing_sale_path(@sale, locale: I18n.locale), notice: t('better_together.billing.sales.refund_recorded')
      rescue Refunds::Record::Refused
        redirect_to billing_sale_path(@sale, locale: I18n.locale), alert: t('better_together.billing.sales.refund_refused')
      end

      private

      def record_refund(payment)
        Refunds::Record.call(payment:, amount_cents: amount_cents(payment), idempotency_key: "refund:#{@sale.id}:#{params[:token]}",
                             reason:, recorded_by: current_user.person)
      end

      def set_sale
        @sale = billing_owner.billing_orders.sold_by_platform.find(params[:sale_id])
      end

      # Only a payment made outside the platform: a vendor refund is made at the vendor.
      def offline_payment
        payment = @sale.payments.find(params[:payment_id])
        raise ActiveRecord::RecordNotFound unless Billing.offline_method?(payment.processor)

        payment
      end

      def amount_cents(payment)
        params[:amount].present? ? Currency.to_minor(params[:amount], payment.currency).to_i : payment.refundable_cents
      end

      def reason = Refund::REASONS.include?(params[:reason].to_s) ? params[:reason].to_s : nil
    end
  end
end
