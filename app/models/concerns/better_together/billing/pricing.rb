# frozen_string_literal: true

module BetterTogether
  module Billing
    # An amount in one currency. Needs the columns `amount_cents` and `currency`. Include it after Purchasable, which it
    # answers for. Shared by everything that has a price.
    module Pricing
      extend ActiveSupport::Concern

      # ISO 4217 alpha-3 codes this platform accepts for a price.
      # A superset of Billing::Currency::SYMBOLS: a currency can be billed
      # without a curated symbol (display falls back to the raw code).
      SUPPORTED_CURRENCY_CODES = %w[
        AUD BRL CAD CHF CNY DKK EUR GBP HKD INR
        JPY KRW MXN NOK NZD PLN SEK SGD USD ZAR
      ].freeze

      included do
        validates :currency, presence: true
        validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
        validates :currency, length: { is: 3 }, inclusion: { in: SUPPORTED_CURRENCY_CODES }
      end

      # Costs nothing, so there is nothing to pay and no way of paying to choose.
      def free?
        amount_cents.to_i.zero?
      end

      def purchasable_amount_cents = amount_cents
      def purchasable_currency = currency
    end
  end
end
