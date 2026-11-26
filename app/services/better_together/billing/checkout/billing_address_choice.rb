# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The billing address a buyer picked at checkout: one of their own addresses, or a new one typed in on the page.
      #
      # Every order needs one, and it must say the state or province and the country as records (a chosen country and state,
      # not typed text), because that is what tax is worked out from. A new address is saved to the buyer's own addresses.
      # With `make_default`, the address also becomes their default billing address on this platform.
      #
      # Returns a Result with the address, or the reason there is none: `:missing`, `:not_found`, `:incomplete` (no chosen
      # country or state) or `:invalid` (a new address that does not save; its errors are on `address`).
      class BillingAddressChoice
        Result = Struct.new(:address, :error) do
          def ok? = error.nil?
        end

        NEW_ATTRIBUTES = %i[line1 line2 postal_code country_id state_id settlement_id country_name state_province_name city_name].freeze

        def self.call(...) = new(...).call

        def initialize(platform:, person:, address_id: nil, new_address: nil, make_default: false)
          @platform = platform
          @person = person
          @address_id = address_id.presence
          @new_address = new_address
          @make_default = make_default
        end

        def call
          result = new_address? ? create_new : find_existing
          return result unless result.ok?

          return Result.new(result.address, :incomplete) unless complete?(result.address)

          make_default!(result.address) if @make_default
          result
        end

        private

        def new_address? = @address_id == 'new'

        def find_existing
          return Result.new(nil, :missing) if @address_id.blank?

          address = @person.addresses.find_by(id: @address_id)
          address ? Result.new(address) : Result.new(nil, :not_found)
        end

        def create_new
          address = @person.contact_detail.addresses.build(new_attributes)
          return Result.new(address, :invalid) unless address.valid?
          return Result.new(address, :incomplete) unless complete?(address)

          save(address)
        end

        def save(address)
          address.save ? Result.new(address) : Result.new(address, :invalid)
        end

        def new_attributes
          permitted = @new_address.respond_to?(:permit) ? @new_address.permit(*NEW_ATTRIBUTES) : @new_address.to_h.slice(*NEW_ATTRIBUTES)
          permitted.to_h.merge(label: 'billing', physical: false, postal: true, privacy: 'private')
        end

        def complete?(address) = address.country_id.present? && address.state_id.present?

        def make_default!(address)
          DefaultAddress.set!(platform: @platform, person: @person, address:, kind: 'billing')
        end
      end
    end
  end
end
