# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Where a walk-up buyer is, for tax: an ISO country code and the state or province's code. A country and state chosen
      # from the geography records are used as they are; typed text is matched on an ISO code or a name. Nothing found means
      # tax is worked out for the seller's own place, as for any order without one.
      class TaxAddress
        def self.call(...) = new(...).call

        def initialize(address, snapshot)
          @address = address
          @snapshot = snapshot.to_h
        end

        def call
          country = @address&.country || country_from(@snapshot['country_name'])
          return {} unless country

          state = @address&.state || state_from(country, @snapshot['state_province_name'])
          { country_iso: country.iso_code, region_code: state && state.iso_code.split('-', 2).last }.compact
        end

        private

        def country_from(entry)
          return if entry.blank?

          Geography::Country.find_by(iso_code: entry.strip.upcase) || Geography::Country.i18n.find_by(name: entry.strip)
        end

        def state_from(country, entry)
          return if entry.blank?

          code = "#{country.iso_code}-#{entry.strip.upcase}"
          Geography::State.find_by(iso_code: code) || country.states.i18n.find_by(name: entry.strip)
        end
      end
    end
  end
end
