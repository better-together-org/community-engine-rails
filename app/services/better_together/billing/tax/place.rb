# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      # Where a sale is taxed, as geography records: the country, the state or province in it, and the settlement
      # (city or town) in that. It is made from what a buyer's address gives: a settlement alone is enough, because
      # a settlement knows its state and country; otherwise an ISO country code and a region code. Whatever is not
      # found is left empty, and a zone that needs it does not apply.
      class Place
        attr_reader :country, :state, :settlement

        def self.resolve(country_iso: nil, region_code: nil, settlement: nil) = new(country_iso:, region_code:, settlement:)

        def initialize(country_iso:, region_code:, settlement:)
          @settlement = settlement
          @state = settlement&.state || find_state(country_iso, region_code)
          @country = settlement&.country || state&.country || find_country(country_iso)
        end

        def country_iso = country&.iso_code
        # The part of the state's ISO code after the country ("CA-NL" is "NL").
        def region_code = state && state.iso_code.split('-', 2).last

        private

        def find_country(country_iso)
          iso = country_iso.to_s.upcase.presence
          iso && Geography::Country.find_by(iso_code: iso)
        end

        def find_state(country_iso, region_code)
          iso = country_iso.to_s.upcase.presence
          region = region_code.to_s.upcase.presence
          iso && region && Geography::State.find_by(iso_code: "#{iso}-#{region}")
        end
      end
    end
  end
end
