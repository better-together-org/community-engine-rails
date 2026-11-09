# frozen_string_literal: true

# Tax zones are tied to the geography rows, so billing tax specs need a country and state for an ISO code. These find
# the row if an earlier example made it (the geography tables are not cleared between examples that share a country)
# and make it if not.
module BillingTaxGeography
  def tax_geography_country(iso)
    iso = iso.to_s.upcase
    BetterTogether::Geography::Country.find_by(iso_code: iso) ||
      FactoryBot.create(:geography_country, iso_code: iso, identifier: "country-#{iso.downcase}", name: iso)
  end

  def tax_geography_state(country_iso, region)
    country = tax_geography_country(country_iso)
    iso = "#{country.iso_code}-#{region.to_s.upcase}"
    BetterTogether::Geography::State.find_by(iso_code: iso) ||
      FactoryBot.create(:geography_state, country:, iso_code: iso, identifier: "state-#{iso.downcase}", name: iso)
  end
end

FactoryBot::SyntaxRunner.include(BillingTaxGeography)
RSpec.configure { |config| config.include BillingTaxGeography }
