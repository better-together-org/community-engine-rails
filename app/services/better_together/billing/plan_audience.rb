# frozen_string_literal: true

module BetterTogether
  module Billing
    # The people who already have a plan: its subscribers and the buyers of its paid one-time orders. A change to
    # what the plan includes reaches exactly these (see SyncPlanEntitlementsJob), so the steward is told how many
    # before they make it.
    class PlanAudience
      PAID = %w[paid partially_refunded refunded].freeze

      # Active subscribers per plan id for a whole list of plans, in one grouped query (the same "active" the
      # subscribers screen filters by). Plans nobody pays for are absent: read it with `counts.fetch(id, 0)`.
      def self.active_subscriber_counts(plans)
        SubscriptionTerm.joins(:pay_subscription).where(plan_id: plans.map(&:id), pay_subscriptions: { status: 'active' }).group(:plan_id).count
      end

      def initialize(plan)
        @plan = plan
      end

      # A product is only bought, never subscribed to; its buyers are those whose order has a line for one of its prices.
      def terms = plan.is_a?(Plan) ? plan.platform.billing_subscription_terms.where(plan_id: plan.id) : SubscriptionTerm.none

      def paid_orders
        plan.platform.billing_orders.where(status: PAID).where(id: LineItem.where(purchasable_type:, purchasable_id:).select(:order_id))
      end

      def count = terms.count + paid_orders.count

      private

      attr_reader :plan

      def purchasable_type = Price.name
      def purchasable_id = plan.prices.select(:id)
    end
  end
end
