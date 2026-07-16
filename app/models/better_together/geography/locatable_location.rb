# frozen_string_literal: true

module BetterTogether
  module Geography
    # Join record between polymorphic locatable and polymorphic location
    class LocatableLocation < ApplicationRecord # rubocop:todo Metrics/ClassLength
      include Creatable

      belongs_to :locatable, polymorphic: true
      belongs_to :location, polymorphic: true, optional: true

      # Handle nested attributes for polymorphic `location` manually because
      # ActiveRecord doesn't support building polymorphic belongs_to via
      # accepts_nested_attributes_for. The form submits a `location_attributes`
      # hash describing any Geography::Placeable-including model (Address, Building,
      # Settlement, Region, ...); this setter builds or assigns the proper associated
      # record.
      #
      # Dynamic extension point (see docs/developers/architecture/
      # polymorphic_allowlist_extension_audit.md): the set of valid location types comes
      # from Placeable.included_in_models, not a hardcoded case/when — a model becomes a
      # valid location_type purely by including Geography::Placeable, with no other change
      # required here. Each Placeable model owns its own build behavior via
      # .locatable_location_build(attrs) (lookup-only by default; Address/Building override
      # it to build a new nested record).
      def location_attributes=(attrs)
        attrs = attrs.to_h.stringify_keys

        # Reject obviously blank nested payloads (mirror previous reject_if logic)
        return if attrs.blank? || (attrs['id'].blank? && attrs.except('id', '_destroy').values.all?(&:blank?))

        allowed_names = BetterTogether::Geography::Placeable.included_in_models.map(&:name)

        if attrs['id'].present?
          assign_location_by_id(attrs['id'], allowed_names)
        else
          assign_location_by_type(attrs, allowed_names)
        end
      end

      # If a persisted nested location is submitted with all empty fields, mark it
      # for destruction so accepts_nested_attributes_for with allow_destroy will remove it
      before_validation :mark_for_destruction_if_empty

      # Validate name only for simple locations and not when marked for destruction
      validates :name, presence: true, if: -> { simple_location? && !marked_for_destruction? }
      validate :at_least_one_location_source, unless: :marked_for_destruction?

      def self.permitted_attributes(id: false, destroy: false)
        super + %i[
          name locatable_id locatable_type location_id location_type
        ] + [
          {
            # Merge permitted attributes across every Placeable-including model, so the
            # params hash allows keys for whichever polymorphic type the form submits —
            # dynamically discovered, not hardcoded to Address/Building.
            location_attributes: BetterTogether::Geography::Placeable.included_in_models.flat_map do |klass|
              klass.respond_to?(:permitted_attributes) ? klass.permitted_attributes(id: true, destroy: true) : []
            end.uniq
          }
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

      # Convenience methods for specific location types. Check the loaded `location`
      # object's actual class via `is_a?`, not the raw `location_type` string column —
      # `Infrastructure::Building` has STI (`type` column), and a string-equality check
      # against the base class name would go false for any future subtype even though
      # `is_a?` correctly still matches it.
      def address
        location if address?
      end

      def building
        location if building?
      end

      def settlement
        location if settlement?
      end

      def region
        location if region?
      end

      # Check if location is of a specific type
      def address?
        location.is_a?(BetterTogether::Address)
      end

      def building?
        location.is_a?(BetterTogether::Infrastructure::Building)
      end

      # Settlement/Region checks reference Locatable::Many::LEVELS (the single canonical
      # hierarchy level => class mapping) rather than a second hardcoded class reference.
      def settlement?
        location.is_a?(BetterTogether::Geography::Locatable::Many::LEVELS[:settlement])
      end

      def region?
        location.is_a?(BetterTogether::Geography::Locatable::Many::LEVELS[:region])
      end

      # Helper method for forms - get available addresses for the user/context
      def self.available_addresses_for(context = nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
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
      def self.available_buildings_for(context = nil) # rubocop:todo Metrics/MethodLength
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

      # Settlement/Region are global curated reference data (no privacy column, no
      # creator-based visibility), unlike Address/Building — so no policy scoping is
      # needed. `context` is accepted only for call-site symmetry with
      # .available_addresses_for/.available_buildings_for.
      def self.available_settlements_for(_context = nil)
        BetterTogether::Geography::Settlement.i18n.order(:name)
      end

      def self.available_regions_for(_context = nil)
        BetterTogether::Geography::Region.i18n.order(:name)
      end

      private

      # If an id is provided, prefer reusing the existing record — look it up across every
      # allowed type, matching the prior Address-or-Building-only behavior.
      def assign_location_by_id(id, allowed_names)
        found = allowed_names.filter_map { |name| name.constantize.find_by(id:) }.first
        self.location = found if found
      end

      def assign_location_by_type(attrs, allowed_names)
        target_type = attrs['location_type'].presence || location_type
        klass = BetterTogether::SafeClassResolver.resolve(target_type, allowed: allowed_names)

        if klass
          self.location = klass.locatable_location_build(attrs.except('locatable_id', 'locatable_type'))
        elsif attrs['name'].present?
          # Fallback: treat as simple named location
          self.name = attrs['name']
        end
      end

      def mark_for_destruction_if_empty
        # Only mark for destruction if this is a persisted nested record that becomes empty
        # Don't auto-mark new records for destruction as they should validate normally
        return unless persisted?

        name_blank = name.blank?
        location_blank = location.blank?

        # If both the simple name and structured location are blank, mark for destruction
        # for persisted records so accepts_nested_attributes_for with allow_destroy will remove them
        mark_for_destruction if name_blank && location_blank
      end

      def at_least_one_location_source
        # If this record is scheduled for destruction or otherwise empty, don't add errors here
        return if marked_for_destruction?

        sources = [name.present?, location.present?]
        return if sources.any?

        errors.add(:base, I18n.t('better_together.geography.locatable_location.errors.no_location_source',
                                 default: 'Must specify either a name or location'))
      end
    end
  end
end
