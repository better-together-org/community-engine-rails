# frozen_string_literal: true

module BetterTogether
  # A billing address a buyer can pick at checkout: one of their own, with a chosen country, state and settlement.
  module BillingAddressHelpers
    def create_billing_address_for(person, country_iso: 'CA', region: 'NL', settlement_name: 'Corner Brook')
      country = BetterTogether::Geography::Country.find_by(iso_code: country_iso) ||
                create(:geography_country, iso_code: country_iso, name: country_iso)
      state = BetterTogether::Geography::State.find_by(iso_code: "#{country_iso}-#{region}") ||
              create(:geography_state, country:, iso_code: "#{country_iso}-#{region}", name: region)
      settlement = create(:geography_settlement, country:, state:, name: settlement_name)
      person.contact_detail.addresses.create!(label: 'billing', physical: false, postal: true, privacy: 'private',
                                              line1: '1 Main St', postal_code: 'A2H 1A1', country:, state:, settlement:)
    end

    # The checkout parameter that picks `address`.
    def billing_address_params(address) = { billing_address_id: address.id }
  end
end
