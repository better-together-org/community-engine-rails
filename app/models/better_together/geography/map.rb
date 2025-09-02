# frozen_string_literal: true

module BetterTogether
  module Geography
    # Spatial representations of data
    class Map < ApplicationRecord
      include Creatable # Tracks the Creator of the record
      include FriendlySlug # Generates friendly slugs for URLs
      include Identifier # Adds unique identifier functionality
      include Privacy # Manages privacy settings
      include Protected # Adds protection mechanisms
      include Viewable # Tracks view counts and related metrics

      belongs_to :mappable, polymorphic: true, optional: true

      delegate :spaces, :leaflet_points, to: :mappable, allow_nil: true

      slugged :title

      translates :title
      translates :description, backend: :action_text

      validates :center, presence: true
      validates :zoom, numericality: { only_integer: true, greater_than: 0 }

      before_validation :set_default_center, on: :create

      def self.permitted_attributes(id: false, destroy: false)
        super + %i[type zoom center]
      end

      def center
        super || default_center
      end

      def set_default_center
        self.center ||= default_center
      end

      # Returns a default center as a PostGIS point using RGeo.
      def default_center
        # Get defaults from ENV or fallback to Corner Brook, NL coordinates.
        lon = ENV.fetch('DEFAULT_MAP_CENTER_LNG', '-57.9474').to_f
        lat = ENV.fetch('DEFAULT_MAP_CENTER_LAT', '48.9517').to_f
        # Creates a spherical geographic factory with SRID 4326.
        # SRID 4326 is a standard spatial reference system identifier that represents
        # the WGS 84 coordinate system, which is a global standard for latitude and longitude.
        # This factory can be used to create geographic objects such as points, lines, and polygons
        # that are interpreted on a spherical model of the Earth.
        factory = RGeo::Geographic.spherical_factory(srid: 4326)
        factory.point(lon, lat)
      end

      # Converts the center attribute to a format that Leaflet expects
      def center_for_leaflet
        "#{center.latitude},#{center.longitude}"
      end

      def leaflet_points # rubocop:todo Lint/DuplicateMethods
        mappable&.leaflet_points || []
      end

      def spaces_for_leaflet
        spaces.map(&:to_leaflet_point).compact.to_json
      end

      def title(options = {}, locale: I18n.locale)
        result = super(**options, locale:)

        result = 'map' if persisted? && result.blank?

        return result unless mappable_id.present?

        mappable.to_s
      end

      def to_partial_path
        'better_together/geography/maps/map'
      end

      def to_s
        title
      end
    end
  end
end

require 'better_together/geography/community_map'
require 'better_together/geography/community_collection_map'
