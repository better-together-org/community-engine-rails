# frozen_string_literal: true

module BetterTogether
  module Billing
    # A buyer's own orders: what they bought, and where each payment stands. Orders are
    # reached only through the platform and only for the signed-in person, so another buyer's
    # order is a 404 whatever id is sent.
    class OrdersController < ApplicationController
      include OwnerScoped

      before_action :set_order, only: :show
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::Order
        @orders = policy_scope(billing_owner.billing_orders).newest_first
      end

      def show
        authorize @order
      end

      private

      def set_order
        @order = billing_owner.billing_orders.bought_by(current_user.person).find(params[:id])
      end
    end
  end
end
