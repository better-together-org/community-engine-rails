# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards see what their platform itself sells: the orders, who placed them, and where
    # each payment stands. Orders sold by a community or person are theirs, not listed here.
    class SalesController < ApplicationController
      include OwnerScoped

      PER_PAGE = 50

      before_action :set_order, only: %i[show return_payments cancel]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Order, :sales?
        @orders = platform_orders.includes(buyer: :string_translations).newest_first.page(params[:page]).per(PER_PAGE)
      end

      def show
        authorize @order, :sale?
      end

      # Gives back every part paid from store credit, in one step. Cash and the like is handed back by the seller (the
      # refund forms below it); a processor refunds at the vendor.
      def return_payments
        authorize @order, :cancel?
        Orders::ReturnPayments.call(order: @order, actor: current_user.person)
        redirect_to billing_sale_path(@order, locale: I18n.locale), notice: t('better_together.billing.sales.returned')
      rescue Refunds::Record::Refused
        redirect_to billing_sale_path(@order, locale: I18n.locale), alert: t('better_together.billing.sales.return_refused')
      end

      # Cancels an order nobody is paying for any longer. Refused while money is still against it: return each part first.
      def cancel
        authorize @order, :cancel?
        Orders::Cancel.call(@order)
        redirect_to billing_sale_path(@order, locale: I18n.locale), notice: t('better_together.billing.sales.cancelled')
      rescue Orders::Cancel::Refused
        redirect_to billing_sale_path(@order, locale: I18n.locale), alert: t('better_together.billing.sales.cancel_refused')
      end

      private

      def platform_orders = billing_owner.billing_orders.sold_by_platform

      def set_order
        @order = platform_orders.find(params[:id])
      end
    end
  end
end
