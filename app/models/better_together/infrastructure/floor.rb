# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents Floors in a Building
    class Floor < PlatformRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Placeable
      include Positioned
      include Privacy
      include PrimaryCommunity

      has_community

      after_create :ensure_room

      belongs_to :building, class_name: 'BetterTogether::Infrastructure::Building', touch: true
      has_many :rooms, class_name: 'BetterTogether::Infrastructure::Room', dependent: :destroy

      # Floors have no independent space of their own — every geospatial read
      # resolves through the building they belong to.
      delegate :space, :latitude, :longitude, :elevation, :geocoded, :geocoded?,
               to: :building, allow_nil: true

      translates :name, type: :string

      slugged :name

      validates :level,
                numericality: { only_integer: true },
                uniqueness: { scope: %i[building_id] },
                presence: true

      def ensure_room
        return if rooms.size.positive?

        rooms.create(name: 'Main')
      end

      def to_s
        name
      end

      # Mirrors Geospatial::One#to_leaflet_point, but keeps the floor's own name as
      # the map label while sourcing coordinates from the delegated building.
      def to_leaflet_point
        return nil unless geocoded?

        {
          lat: latitude,
          lng: longitude,
          elevation: elevation,
          label: to_s
        }
      end
    end
  end
end
