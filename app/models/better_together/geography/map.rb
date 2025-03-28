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
      include Searchable # Enables search capabilities
      include Viewable # Tracks view counts and related metrics

      slugged :title

      translates :title
      translates :description, backend: :action_text

      validates :center, presence: true
      validates :zoom, numericality: { only_integer: true, greater_than: 0 }

      before_validation :set_default_center, on: :create

      settings index: { number_of_shards: 1 } do
        mappings dynamic: 'false' do
          indexes :title, as: 'title'
          indexes :description, as: 'description'
          indexes :rich_text_content, type: 'nested' do
            indexes :body, type: 'text'
          end
          indexes :rich_text_translations, type: 'nested' do
            indexes :body, type: 'text'
          end
        end
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

      def to_s
        title
      end
    end
  end
end
