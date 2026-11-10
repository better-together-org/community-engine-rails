# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # What the checkout's billing address picker offers a buyer: their own addresses that have a chosen country and
      # state (what tax needs), their default billing address first, the one to preselect, and a blank new address.
      class BillingAddressOptions
        def initialize(platform:, person:, selected_id: nil)
          @platform = platform
          @person = person
          @selected_id = selected_id.presence
        end

        def addresses
          @addresses ||= @person.addresses.where.not(country_id: nil).where.not(state_id: nil)
                                .sort_by { |address| address.id == default_id ? 0 : 1 }
        end

        def selected_id = @selected_id || default_id

        def blank_address = @person.contact_detail.addresses.build

        private

        def default_id
          return @default_id if defined?(@default_id)

          @default_id = @person.billing_default_addresses.billing.find_by(platform: @platform)&.address_id
        end
      end
    end
  end
end
