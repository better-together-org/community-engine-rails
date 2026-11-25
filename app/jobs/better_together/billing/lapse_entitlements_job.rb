# frozen_string_literal: true

module BetterTogether
  module Billing
    # Ends what a fixed-term purchase gave once its term is over: each live entitlement from an order whose end date has
    # passed is brought in line again, which lapses it and takes back its grants. It also finishes a release that failed
    # earlier: an entitlement that is no longer live but still holds applied grants is brought in line again too, so
    # access or quota never stays behind. A maintenance sweep, acting on one order at a time; one order failing does not
    # stop the others, and the next sweep tries it again. Safe to repeat.
    class LapseEntitlementsJob < ApplicationJob
      def perform
        failed = Order.where(id: order_ids).find_each.filter_map { |order| sync(order) }
        Rails.logger.warn("[billing] #{failed.size} order(s) not fully released; the next sweep retries them") if failed.any?
      end

      private

      def order_ids
        ended = Entitlement.live.where(ends_at: ..Time.current)
        unreleased = Entitlement.where.not(status: Entitlement::LIVE).where(id: EntitlementGrant.applied.select(:entitlement_id))
        ended.or(unreleased).where.not(order_id: nil).distinct.pluck(:order_id)
      end

      # Returns the order when it could not be brought fully in line.
      def sync(order)
        Entitlements::Sync.order(order)
        nil
      rescue Entitlements::Sync::Incomplete => e
        Rails.logger.warn("[billing] order #{order.id} entitlement not fully synced: #{e.message}")
        order
      end
    end
  end
end
