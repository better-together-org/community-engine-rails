# frozen_string_literal: true

module BetterTogether
  module Geography
    # Join record between polymorphic locatable and polymorphic location
    class LocatableLocation < ApplicationRecord
      include Creatable

      belongs_to :locatable, polymorphic: true
      belongs_to :location, polymorphic: true, optional: true

      validates :name, presence: true, if: :simple_location?
      validate :at_least_one_location_source

      def self.permitted_attributes(id: false, destroy: false)
        super + %i[
          name locatable_id locatable_type location_id location_type
        ]
      end

      def to_s
        display_name
      end

      # Primary display name for the location
      def display_name
        return name if name.present?
        return location.to_s if location.present?

        'Unnamed Location'
      end

      # Full address string for geocoding
      def geocoding_string
        return location.geocoding_string if location.respond_to?(:geocoding_string)

        name # fallback to string location
      end

      # Check if this is a simple string-based location
      def simple_location?
        location.blank?
      end

      # Check if this has structured location data
      def structured_location?
        !simple_location?
      end

      # Convenience methods for specific location types
      def address
        location if location_type == 'BetterTogether::Address'
      end

      def building
        location if location_type == 'BetterTogether::Infrastructure::Building'
      end

      # Check if location is of a specific type
      def address?
        location_type == 'BetterTogether::Address'
      end

      def building?
        location_type == 'BetterTogether::Infrastructure::Building'
      end

      # Helper method for forms - get available addresses for the user/context
      def self.available_addresses_for(_context = nil)
        # This would be customized based on your business logic
        # For example, user's addresses, community addresses, etc.
        BetterTogether::Address.includes(:string_translations)
      end

      # Helper method for forms - get available buildings for the user/context
      def self.available_buildings_for(_context = nil)
        # This would be customized based on your business logic
        BetterTogether::Infrastructure::Building.includes(:string_translations)
      end

      private

      def at_least_one_location_source
        sources = [name.present?, location.present?]
        return if sources.any?

        errors.add(:base, I18n.t('better_together.geography.locatable_location.errors.no_location_source',
                                 default: 'Must specify either a name or location'))
      end
    end
  end
end
