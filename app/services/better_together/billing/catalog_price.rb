# frozen_string_literal: true

module BetterTogether
  module Billing
    # One price of a catalog item, as core hands it to an adapter to create or update. `ref` is core's own id for it
    # (a Price id, or the plan's id) and comes back on the matching PriceInfo, so core never guesses which processor price
    # is which. `interval` is 'one_time' or one of Plan::BILLING_INTERVALS. `processor_price_id` is set once it exists.
    CatalogPrice = Data.define(:ref, :amount_cents, :currency, :interval, :interval_count, :active, :processor_price_id, :lookup_key)
  end
end
