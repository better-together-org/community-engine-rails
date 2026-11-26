# frozen_string_literal: true

module BetterTogether
  # Words for a price, shared by the plan and product pages.
  module BillingPriceHelper
    # A price in words: "$10.00 a month", "$100.00 a year", "$5.00 once".
    def billing_price_terms(price)
      amount = billing_amount(price.amount_cents, price.currency)
      return t('better_together.billing.catalog.price.once', price: amount) unless price.recurring?

      count = price.interval_count.to_i
      key = count > 1 ? "every_n_#{price.interval}s" : price.interval
      t("better_together.billing.catalog.price.#{key}", price: amount, count:)
    end
  end
end
