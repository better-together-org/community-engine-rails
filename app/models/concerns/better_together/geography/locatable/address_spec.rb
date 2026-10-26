# frozen_string_literal: true

module BetterTogether
  module Geography
    module Locatable
      # Write-only +address_spec+ for a record with a `location` (a has_one LocatableLocation).
      module AddressSpec
        extend ActiveSupport::Concern

        ADDRESS_FIELDS = %w[name line1 line2 city_name state_province_name postal_code country_name].freeze
        ADDRESS_MATCH_FIELDS = %w[line1 city_name postal_code country_name].freeze

        included do
          validate :address_spec_must_be_valid
        end

        # Write-only API input: locates the record at a street address, given as a hash or a JSON string (the
        # JSON:API rejects nested objects) with line1, line2, city_name, state_province_name, postal_code,
        # country_name and an optional name for the place. An existing address with the same line1, city, postal
        # code and country is reused; otherwise a public one is created. Blank clears the location.
        def address_spec
          nil
        end

        def address_spec=(spec)
          @address_spec_error = nil
          if spec.blank?
            location&.mark_for_destruction
          else
            locate_at_address(spec)
          end
        rescue JSON::ParserError
          @address_spec_error = 'is not valid JSON'
        end

        private

        def address_spec_must_be_valid
          errors.add(:address_spec, @address_spec_error) if @address_spec_error
        end

        def locate_at_address(spec)
          attrs = parse_address_spec(spec)
          return @address_spec_error = 'must be an address with line1' if attrs['line1'].blank?

          name = attrs.delete('name') # a location is shown only when it has a name
          place = location || build_location
          place.assign_attributes(location: address_for(attrs), name: name.presence || place.name)
        end

        def parse_address_spec(spec)
          spec = JSON.parse(spec) if spec.is_a?(String)
          spec.to_h.stringify_keys.slice(*ADDRESS_FIELDS).transform_values { |value| value.to_s.strip }.compact_blank
        end

        def address_for(attrs)
          BetterTogether::Address.find_by(attrs.slice(*ADDRESS_MATCH_FIELDS)) ||
            BetterTogether::Address.new(attrs.merge('physical' => true, 'postal' => false, 'privacy' => 'public'))
        end
      end
    end
  end
end
