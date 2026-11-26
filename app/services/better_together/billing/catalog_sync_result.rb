# frozen_string_literal: true

module BetterTogether
  module Billing
    # What ProcessorAdapter#sync_catalog_item did: the processor's product id, and a PriceInfo for each price of the item (created,
    # or the one that was already there), each carrying the `ref` of the CatalogPrice it answers. Core stores it; the adapter
    # never writes a plan, product or price.
    CatalogSyncResult = Data.define(:product_id, :prices) do
      # The PriceInfo answering the CatalogPrice with this ref, or nil.
      def price_for(ref) = prices.find { |info| info.ref.to_s == ref.to_s }
    end
  end
end
