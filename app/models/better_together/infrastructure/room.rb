# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents rooms on a floor in a building
    class Room < PlatformRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Placeable
      include Privacy
      include PrimaryCommunity

      has_community

      belongs_to :floor, class_name: 'BetterTogether::Infrastructure::Floor', touch: true
      has_one :building, through: :floor, class_name: 'BetterTogether::Infrastructure::Building'

      delegate :level, to: :floor

      # Rooms have no independent space of their own — every geospatial read
      # resolves through the building they belong to.
      delegate :space, :latitude, :longitude, :elevation, :geocoded, :geocoded?,
               to: :building, allow_nil: true

      translates :name, type: :string

      slugged :name

      def to_s
        name
      end

      # Mirrors Geospatial::One#to_leaflet_point, but keeps the room's own name as
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
