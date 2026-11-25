# frozen_string_literal: true

module BetterTogether
  module Billing
    # Ends what a fixed-term purchase gave once its term is over: each live entitlement from an order whose end date has
    # passed is brought in line again, which lapses it and takes back its grants. A maintenance sweep, acting on one
    # order at a time. Safe to repeat.
    class LapseEntitlementsJob < ApplicationJob
      def perform
        order_ids = Entitlement.live.where.not(order_id: nil).where(ends_at: ..Time.current).distinct.pluck(:order_id)
        Order.where(id: order_ids).find_each { |order| Entitlements::Sync.order(order) }
      end
    end
  end
end
