# frozen_string_literal: true

module BetterTogether
  module Billing
    # Stewards see what their platform itself sells: the orders, who placed them, and where
    # each payment stands. Orders sold by a community or person are theirs, not listed here.
    class SalesController < ApplicationController
      include OwnerScoped

      before_action :set_order, only: :show
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Order, :sales?
        @orders = platform_orders.includes(:buyer).newest_first
      end

      def show
        authorize @order, :sale?
      end

      private

      def platform_orders = billing_owner.billing_orders.sold_by_platform

      def set_order
        @order = platform_orders.find(params[:id])
      end
    end
  end
end
