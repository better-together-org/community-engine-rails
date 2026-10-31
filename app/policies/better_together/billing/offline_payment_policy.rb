# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::OfflinePayment: the seller's queue of payments made outside the
    # platform, and what they can do with each. Through the same #manage_billing? question as plans
    # and orders. Payments for what a community or person sells belong to that seller and are not
    # visible through the platform's screens. The buyer's own part (saying they sent it) is the
    # order policy's `claim?`.
    class OfflinePaymentPolicy < OwnerPolicy
      def index? = manage_billing?
      def receive? = platform_sale?
      def reject? = platform_sale?
      def clear? = platform_sale?
      def bounce? = platform_sale?
      def show? = false
      def create? = false
      def update? = false
      def destroy? = false

      # What the platform itself sells, for a steward; nothing for anyone else.
      class Scope < OwnerPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless user && platform && available?(platform) && user.permitted_to?(:manage_platform, platform)

          scope.for_platform(platform).where(order_id: platform.billing_orders.sold_by_platform.select(:id))
        end
      end

      private

      def platform_sale? = manage_billing? && record.try(:order)&.sold_by_platform?
    end
  end
end
