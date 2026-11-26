# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a buyer pays for at the processor, with no price in the processor's catalog: the amount, currency and, for something
    # that recurs, its interval, plus the product text to show. Stripe takes this inline as `price_data` and `product_data`.
    InlinePrice = Data.define(:amount_cents, :currency, :interval, :interval_count, :name, :description) do
      def recurring? = interval != 'one_time'
    end
  end
end
