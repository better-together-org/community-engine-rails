# frozen_string_literal: true

require 'activerecord-postgis-adapter'

# This migration adds center, zoom, viewport, and metadata columns to the geography_maps table.
# It is intended to enhance the geographical mapping capabilities by storing additional information
# about the map's center coordinates, zoom level, viewport dimensions, and other relevant metadata.
class AddCenterZoomViewportAndMetadataToGeographyMaps < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis' unless extension_enabled?('postgis')

    # Set default values from ENV or fallback to Corner Brook, NL coordinates.
    default_lng = ENV.fetch('DEFAULT_MAP_CENTER_LNG', '-57.9474')
    default_lat = ENV.fetch('DEFAULT_MAP_CENTER_LAT', '48.9517')
    center_default = "POINT (#{default_lng} #{default_lat})"

    change_table :better_together_geography_maps do |t|
      # New PostGIS column for the map center with a SQL default expression.
      t.st_point 'center', geographic: true, null: false, default: center_default
      t.integer 'zoom', null: false, default: 13

      # Additional metadata: a viewport polygon for the map's visible boundaries.
      t.st_polygon 'viewport', geographic: true

      # A JSONB column for any extra metadata you might want to store.
      t.jsonb 'metadata', default: {}, null: false
    end
  end
end
