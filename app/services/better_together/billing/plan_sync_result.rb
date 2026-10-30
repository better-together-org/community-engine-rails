# frozen_string_literal: true

module BetterTogether
  module Billing
    # What ProcessorAdapter#sync_plan did: the product, and the price (created, or the
    # existing one) as a PriceInfo. Core stores it; the adapter never writes the plan.
    PlanSyncResult = Data.define(:product_id, :price)
  end
end
