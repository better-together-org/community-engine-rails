# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents a building in the real world
    class Building < PlatformRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Geography::Locatable::Many
      include Geography::Placeable
      include Privacy
      include PrimaryCommunity

      has_community

      belongs_to :address,
                 -> { where(physical: true, primary_flag: true) }

      has_many :building_connections,
               class_name: 'BetterTogether::Infrastructure::BuildingConnection',
               dependent: :destroy

      has_many :floors,
               -> { order(:level) },
               class_name: 'BetterTogether::Infrastructure::Floor',
               dependent: :destroy

      has_many :rooms,
               through: :floors,
               class_name: 'BetterTogether::Infrastructure::Room',
               dependent: :destroy

      accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?

      delegate :geocoding_string, to: :address, allow_nil: true

      # Building geocodes its address (schedule_address_geocoding below, driven off
      # address_changed?), not itself, so skip the generic self-geocoding hooks
      # Geospatial::One registers under after_create/after_update :schedule_geocoding —
      # otherwise GeocodingJob.perform_later gets enqueued twice per create/update, once
      # from each callback.
      skip_callback :create, :after, :schedule_geocoding
      skip_callback :update, :after, :schedule_geocoding

      after_create :ensure_floor

      after_create :schedule_address_geocoding
      after_update :schedule_address_geocoding

      translates :name, type: :string
      translates :description, backend: :action_text

      slugged :name

      def self.permitted_attributes(id: false, destroy: false)
        [
          {
            address_attributes: Address.permitted_attributes(id: true)
          }
        ] + super
      end

      # Placeable: reuse an existing Building when the picker selected one (matching
      # Placeable's own default lookup), otherwise build a new Building from nested
      # locatable_location attrs. Building may include nested address attributes; hoist
      # any top-level address attribute keys into address_attributes so Building.new
      # receives them nested as it expects.
      def self.locatable_location_build(attrs) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        existing = find_by(id: attrs['id'] || attrs['location_id'])
        return existing if existing

        attrs = attrs.dup
        address_keys = BetterTogether::Address.permitted_attributes(id: true, destroy: true).grep(Symbol).map(&:to_s)

        attrs['address_attributes'] ||= {}
        address_keys.each do |akey|
          next unless attrs.key?(akey)

          attrs['address_attributes'][akey] = attrs.delete(akey)
        end

        attrs.except!('id', '_destroy', 'location_type', 'name', 'locatable_id', 'locatable_type', 'location_id')

        new(attrs)
      end

      def address?
        address_id.present?
      end

      def name_is_address?
        return false unless address_id

        name == address.geocoding_string
      end

      def ensure_floor
        return if floors.size.positive?

        floors.create(name: 'Ground')
      end

      def schedule_address_geocoding
        return unless should_geocode?

        BetterTogether::Geography::GeocodingJob.perform_later(self)
      end

      def should_geocode?
        return false if geocoding_string.blank?

        # space.reload # in case it has been geocoded since last load

        (address_changed? or !geocoded?)
      end

      def select_option_title
        "#{name} (#{slug})"
      end

      def to_s
        name
      end
    end
  end
end
