# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # What an order keeps of the buyer's billing address, and where tax is worked out from it.
      #
      # The snapshot is plain text as the address read when the order was placed, so editing or deleting the address later
      # never changes the order. The tax place comes from the address's geography links: a settlement if one is chosen
      # (which finds municipal tax), otherwise its country and state ISO codes. A address with neither has no tax place,
      # and tax is then worked out for the registrant's own place.
      class BillingAddressSnapshot
        FIELDS = %i[line1 line2 city_name state_province_name postal_code country_name].freeze

        def initialize(address)
          @address = address
        end

        def to_h
          return {} unless @address

          FIELDS.index_with { |field| @address.public_send(field).to_s.presence }.compact
                .merge('country_iso' => country&.iso_code, 'region_code' => region_code).compact.stringify_keys
        end

        # The `tax_address:` Orders::Place understands.
        def tax_address
          return {} unless @address
          return { settlement: } if settlement

          { country_iso: country&.iso_code, region_code: }.compact
        end

        private

        def settlement = @address.settlement
        def country = @address.country
        def state = @address.state

        # The part of the state's ISO code after the country ("CA-NL" is "NL").
        def region_code = state ? state.iso_code.split('-', 2).last : nil
      end
    end
  end
end
