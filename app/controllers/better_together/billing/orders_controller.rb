# frozen_string_literal: true

module BetterTogether
  module Billing
    # A buyer's own orders: what they bought, and where each payment stands. Orders are
    # reached only through the platform and only for the signed-in person, so another buyer's
    # order is a 404 whatever id is sent.
    class OrdersController < ApplicationController
      include OwnerScoped

      PER_PAGE = 25

      before_action :set_order, only: %i[show pay checkout_return]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Order
        @orders = policy_scope(billing_owner.billing_orders).newest_first.page(params[:page]).per(PER_PAGE)
      end

      def show
        authorize @order
      end

      # Sends the buyer to pay through the processor: its hosted checkout, or its page for a payment
      # that needs them. The address only ever comes from the adapter and is checked to be https.
      def pay
        authorize @order
        redirect_to Checkout::Start.call(order: @order, success_url: checkout_return_billing_order_url(@order, locale: I18n.locale),
                                         cancel_url: billing_order_url(@order, locale: I18n.locale), payment: chosen_payment),
                    allow_other_host: true, status: :see_other
      rescue Checkout::Start::Unavailable
        redirect_to billing_order_path(@order, locale: I18n.locale), alert: t('better_together.billing.orders.pay_unavailable')
      end

      # Where the processor sends the buyer back to. The session in the address is believed only if it is
      # the one we sent them to for this order; the webhook, not this page, decides whether they paid.
      def checkout_return
        authorize @order
        status = Checkout::Return.call(order: @order, session_id: params[:stripe_checkout_session_id].presence || params[:session_id])
        key = status.to_s == 'paid' ? 'return_paid' : 'return_pending'
        redirect_to billing_order_path(@order, locale: I18n.locale), notice: t("better_together.billing.orders.#{key}")
      rescue Checkout::Return::Unrecognised
        redirect_to billing_order_path(@order, locale: I18n.locale), alert: t('better_together.billing.orders.pay_unavailable')
      end

      private

      # Which processor payment to pay when an order has several waiting; only one of this order's own.
      def chosen_payment = (@order.payments.find(params[:payment_id]) if params[:payment_id].present?)

      def set_order
        @order = billing_owner.billing_orders.bought_by(current_user.person).find(params[:id])
      end
    end
  end
end
