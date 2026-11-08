# frozen_string_literal: true

module BetterTogether
  module Billing
    # A processor-side price, as an adapter reports it. Amounts are in the currency's
    # smallest unit; `interval` is one of Plan::BILLING_INTERVALS ('one_time' for a price
    # that does not recur). A plain value, so core never holds a vendor object.
    PriceInfo = Data.define(:price_id, :product_id, :amount_cents, :currency, :interval, :active) do
      def initialize(price_id:, product_id: nil, amount_cents: nil, currency: nil, interval: nil, active: true) # rubocop:disable Metrics/ParameterLists
        super(price_id:, product_id:, amount_cents:, currency: currency&.to_s&.upcase, interval:, active:)
      end

      def active? = active ? true : false
    end
  end
end
