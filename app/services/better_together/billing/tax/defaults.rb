# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      # How a country usually shows prices: with the tax already in them (VAT and GST in much of the world) or
      # with the tax added at the end (Canada, the United States). Only the starting point: a registration can
      # say otherwise.
      module Defaults
        INCLUSIVE_COUNTRIES = %w[
          AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE
          GB AU NZ CH NO IS JP KR IN ZA
        ].freeze

        def self.prices_include_tax?(country_iso) = INCLUSIVE_COUNTRIES.include?(country_iso.to_s.upcase)
      end
    end
  end
end
