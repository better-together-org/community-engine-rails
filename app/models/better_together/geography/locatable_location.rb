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
      def self.available_addresses_for(context = nil)
        return BetterTogether::Address.none unless context

        case context
        when BetterTogether::Person
          # Use policy to get authorized addresses for the person
          user = context.user
          if user
            policy_scope = BetterTogether::AddressPolicy::Scope.new(user, BetterTogether::Address).resolve
            policy_scope.includes(:contact_detail)
          else
            # Person without user - only public addresses
            BetterTogether::Address.where(privacy: 'public').includes(:contact_detail)
          end
        when BetterTogether::Community
          # Communities can access public addresses and their own addresses
          community_address_ids = BetterTogether::Address
                                  .joins(:contact_detail)
                                  .where(better_together_contact_details: { contactable: context })
                                  .pluck(:id)

          public_address_ids = BetterTogether::Address.where(privacy: 'public').pluck(:id)

          # Combine IDs and query with includes
          all_address_ids = (community_address_ids + public_address_ids).uniq
          BetterTogether::Address.where(id: all_address_ids).includes(:contact_detail)
        else
          # Default: return public addresses only
          BetterTogether::Address.where(privacy: 'public').includes(:contact_detail)
        end
      end

      # Helper method for forms - get available buildings for the user/context
      def self.available_buildings_for(context = nil)
        return BetterTogether::Infrastructure::Building.none unless context

        case context
        when BetterTogether::Person
          if context.user
            # Person with user can access buildings they created and public buildings
            BetterTogether::Infrastructure::Building
              .where(creator: context)
              .or(BetterTogether::Infrastructure::Building.where(privacy: 'public'))
              .includes(:string_translations, :address)
          else
            # Person without user - only public buildings
            BetterTogether::Infrastructure::Building
              .where(privacy: 'public')
              .includes(:string_translations, :address)
          end
        when BetterTogether::Community
          # Communities get public buildings for now
          BetterTogether::Infrastructure::Building
            .where(privacy: 'public')
            .includes(:string_translations, :address)
        else
          # Fallback: return empty scope for unsupported context types
          BetterTogether::Infrastructure::Building.none
        end
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
