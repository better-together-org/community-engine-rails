# frozen_string_literal: true

require 'activerecord-postgis-adapter'

# Adds a polygon/multipolygon boundary column to Space so that any geospatial owner
# (Continent/Country/State/Region/Settlement via GeospatialSpace) can store an area,
# not just a point. This is what makes PostGIS containment queries (ST_Contains) possible
# for resolving a geocoded Address/Building/Event point into the geography hierarchy.
class AddBoundaryToBetterTogetherGeographySpaces < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis' unless extension_enabled?('postgis')

    unless column_exists?(:better_together_geography_spaces, :boundary)
      change_table :better_together_geography_spaces do |t|
        t.multi_polygon 'boundary', geographic: true, srid: 4326, null: true
      end
    end

    return if index_exists?(:better_together_geography_spaces, :boundary,
                            name: 'index_better_together_geography_spaces_on_boundary')

    add_index :better_together_geography_spaces, :boundary,
              using: :gist,
              name: 'index_better_together_geography_spaces_on_boundary'
  end
end
