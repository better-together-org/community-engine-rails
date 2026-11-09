# frozen_string_literal: true

module BetterTogether
  module Billing
    # The buyer tells the seller they sent a payment made outside the platform (cash handed over, a
    # cheque posted, an e-transfer sent), with a reference if they like.
    #
    # This is a courtesy and nothing depends on it: the seller can confirm the payment whether or not
    # it was ever sent, and a claim made after the seller confirmed is ignored. The order is reached
    # through the platform and the signed-in buyer, so another buyer's order is a 404.
    class OrderClaimsController < ApplicationController
      include OwnerScoped

      before_action :set_order
      after_action :verify_authorized

      def create
        authorize @order, :claim?
        OfflinePayments::Transition.claim(offline_payment, reference: params[:reference].to_s.strip.first(OfflinePayment::REFERENCE_LIMIT))
        redirect_to billing_order_path(@order, locale: I18n.locale), notice: t('better_together.billing.offline_payments.claimed')
      rescue OfflinePayments::Transition::TooManyClaims
        redirect_to billing_order_path(@order, locale: I18n.locale), alert: t('better_together.billing.offline_payments.too_many_claims')
      end

      private

      def set_order
        @order = billing_owner.billing_orders.bought_by(current_user.person).find(params[:order_id])
      end

      def offline_payment = @order.offline_payments.newest_first.first || raise(ActiveRecord::RecordNotFound)
    end
  end
end
