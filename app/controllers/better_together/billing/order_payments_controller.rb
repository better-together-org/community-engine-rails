# frozen_string_literal: true

module BetterTogether
  module Billing
    # The buyer adds a payment to an order that still has something to pay: "pay the rest", or a part of it, by any way
    # of paying that is open for the order, store credit included. Several parts can complete an order, now or later.
    #
    # The amount is optional (the rest, or for credit all the buyer can spend). The order is reached through the platform
    # and the signed-in buyer, so another buyer's order is a 404, and the amount can never pass what is left to pay.
    class OrderPaymentsController < ApplicationController
      include OwnerScoped

      before_action :set_order
      after_action :verify_authorized

      def create
        authorize @order, :add_payment?
        redirect_to billing_order_path(@order, locale: I18n.locale), notice: notice_for(add_payment)
      rescue Orders::AddPayment::Refused => e
        Rails.logger.warn("[billing] add payment refused: #{e.message}")
        redirect_to billing_order_path(@order, locale: I18n.locale), alert: t('better_together.billing.order_payments.refused')
      end

      private

      def add_payment
        Orders::AddPayment.call(order: @order, payment_method: params[:payment_method].to_s, amount_cents:,
                                idempotency_key: params[:token].presence || SecureRandom.hex(8))
      end

      def set_order
        @order = billing_owner.billing_orders.bought_by(current_user.person).find(params[:order_id])
      end

      def amount_cents
        return if params[:amount].blank?

        Currency.to_minor(params[:amount], @order.currency).to_i
      end

      def notice_for(payment)
        payment.succeeded? ? t('better_together.billing.order_payments.paid') : t('better_together.billing.order_payments.added')
      end
    end
  end
end
