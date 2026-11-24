# frozen_string_literal: true

module BetterTogether
  module Billing
    # A plan's grants changed: bring every entitlement for it up to date, and give a plan that gained its first
    # grant to the subscribers and buyers who already pay. One at a time, so one failure does not stop the rest.
    class SyncPlanEntitlementsJob < ApplicationJob
      def perform(plan)
        audience = PlanAudience.new(plan)
        audience.terms.find_each { |term| sync { Entitlements::Sync.subscription(term) } }
        audience.paid_orders.find_each { |order| sync { Entitlements::Sync.order(order) } }
      end

      private

      def sync
        yield
      rescue StandardError => e
        Rails.logger.error("[billing] could not sync an entitlement: #{e.class}")
        BetterTogether.report_error(e, context: { job: self.class.name })
      end
    end
  end
end
