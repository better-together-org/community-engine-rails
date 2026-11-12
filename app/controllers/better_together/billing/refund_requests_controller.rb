# frozen_string_literal: true

module BetterTogether
  module Billing
    # A buyer asks for money back on one of their orders and can withdraw the request while it waits. Reached through the
    # buyer's own order only, so another person's order is a 404 whatever id is sent.
    class RefundRequestsController < ApplicationController
      include OwnerScoped

      before_action :set_order
      after_action :verify_authorized

      def new
        authorize build_request
      end

      def create
        authorize build_request
        RefundRequests::Create.call(order: @order, requester: current_user.person, reason: params[:reason], amount_cents:,
                                    details: params[:details])
        redirect_to billing_order_path(@order, locale: I18n.locale), notice: t('better_together.billing.refund_requests.sent')
      rescue RefundRequests::Create::Refused => e
        @error = e.message
        render :new, status: :unprocessable_content
      end

      def cancel
        request = @order.refund_requests.find(params[:id])
        authorize request
        request.update!(status: 'cancelled', decided_at: Time.current) if request.pending?
        redirect_to billing_order_path(@order, locale: I18n.locale), notice: t('better_together.billing.refund_requests.withdrawn')
      end

      private

      def build_request
        @refund_request = @order.refund_requests.new(currency: @order.currency, requester: current_user.person)
      end

      def set_order
        @order = billing_owner.billing_orders.bought_by(current_user.person).find(params[:order_id])
      end

      # Empty means "all that can be given back".
      def amount_cents
        params[:amount].present? ? Currency.to_minor(params[:amount], @order.currency).to_i : nil
      end
    end
  end
end
