# frozen_string_literal: true

module BetterTogether
  # View helpers shared by the billing pages.
  module BillingHelper
    def billing_amount(amount_minor, currency)
      number_to_currency(
        BetterTogether::Billing::Currency.to_major(amount_minor, currency),
        unit: BetterTogether::Billing::Currency.unit(currency),
        precision: BetterTogether::Billing::Currency.exponent(currency)
      )
    end

    def billing_interval_label(interval)
      t("better_together.billing.plans.interval_#{interval}", default: interval.to_s.humanize)
    end
  end
end
