# frozen_string_literal: true

module BetterTogether
  # View helpers shared by the billing pages (community/person) and the
  # sponsorship panels rendered inside them.
  module BillingHelper
    # Curated symbol table for the currencies BTS actually bills in today.
    # Plan#currency accepts any ISO 4217 code beyond this list (see
    # Billing::Plan::SUPPORTED_CURRENCY_CODES) - currency_unit falls back to
    # the raw upcased code for anything not covered here, matching Rails'
    # number_to_currency unit: parameter shape.
    CURRENCY_SYMBOLS = {
      'CAD' => 'CA$',
      'USD' => 'US$',
      'EUR' => '€',
      'GBP' => '£'
    }.freeze

    def sponsorship_counterpart_name(entity)
      return t('globals.unknown', default: 'Unknown') if entity.blank?

      entity.respond_to?(:name) ? entity.name : entity.to_s
    end

    def billing_amount(amount_cents, currency)
      number_to_currency(amount_cents.to_i / 100.0, unit: currency_unit(currency))
    end

    def billing_interval_label(interval)
      t("better_together.billing.plans.interval_#{interval}", default: interval.to_s.humanize)
    end

    private

    def currency_unit(currency)
      code = currency.to_s.upcase
      CURRENCY_SYMBOLS.fetch(code, "#{code} ")
    end
  end
end
