# frozen_string_literal: true

module BetterTogether
  module Billing
    # The people who already have a plan: its subscribers and the buyers of its paid one-time orders. A change to
    # what the plan includes reaches exactly these (see SyncPlanEntitlementsJob), so the steward is told how many
    # before they make it.
    class PlanAudience
      PAID = %w[paid partially_refunded refunded].freeze

      def initialize(plan)
        @plan = plan
      end

      def terms = plan.platform.billing_subscription_terms.where(plan_id: plan.id)

      def paid_orders
        plan.platform.billing_orders.where(status: PAID)
            .where(id: LineItem.where(purchasable_type: Plan.name, purchasable_id: plan.id).select(:order_id))
      end

      def count = terms.count + paid_orders.count

      private

      attr_reader :plan
    end
  end
end
