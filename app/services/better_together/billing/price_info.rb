# frozen_string_literal: true

module BetterTogether
  module Billing
    # A processor-side price, as an adapter reports it. Amounts are in the currency's
    # smallest unit; `interval` is one of Plan::BILLING_INTERVALS ('one_time' for a price
    # that does not recur) and `interval_count` how many of them make a period (3 months).
    # `usage_type` is 'licensed' (a fixed price) or 'metered' (billed on usage, which core does not
    # sell). A plain value, so core never holds a vendor object. A price core cannot represent (a
    # weekly or metered one) must be reported as it is: core refuses to link it rather than guess.
    PriceInfo = Data.define(:price_id, :product_id, :amount_cents, :currency, :interval, :interval_count, :usage_type, :active) do
      def initialize(price_id:, product_id: nil, amount_cents: nil, currency: nil, interval: nil, interval_count: 1, # rubocop:disable Metrics/ParameterLists
                     usage_type: 'licensed', active: true)
        super(price_id:, product_id:, amount_cents:, currency: currency&.to_s&.upcase, interval:, interval_count: interval_count || 1,
              usage_type: usage_type.to_s.presence || 'licensed', active:)
      end

      def active? = active ? true : false

      def metered? = usage_type == 'metered'
    end
  end
end
