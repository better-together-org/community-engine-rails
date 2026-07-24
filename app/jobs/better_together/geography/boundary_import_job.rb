# frozen_string_literal: true

require 'rgeo-geojson'

module BetterTogether
  module Geography
    # One-time/admin-triggered import of a boundary polygon for a single
    # Continent/Country/State/Region/Settlement record, from the same Nominatim/Geocoder
    # backend already used for point geocoding (via the `polygon_geojson` search param).
    #
    # Never runs on a live request path — always dispatched from
    # `better_together:geography:import_boundaries` (see lib/tasks), which throttles calls
    # serially to respect Nominatim's usage policy. Idempotent: skips records that already
    # have a boundary unless force_refresh is true.
    class BoundaryImportJob < ApplicationJob
      queue_as :low_priority
      retry_on StandardError, wait: :polynomially_longer, attempts: 3
      discard_on ActiveJob::DeserializationError

      HIERARCHY_LEVELS = [
        BetterTogether::Geography::Continent,
        BetterTogether::Geography::Country,
        BetterTogether::Geography::State,
        BetterTogether::Geography::Region,
        BetterTogether::Geography::Settlement
      ].freeze

      # Orchestrates a full run across every hierarchy level for
      # `better_together:geography:import_boundaries` — perform_now in a straight serial
      # loop, deliberately NOT perform_later, so only one Nominatim polygon_geojson request
      # is ever in flight regardless of Sidekiq concurrency.
      def self.import_all_missing
        imported = 0
        skipped = 0

        HIERARCHY_LEVELS.each do |klass|
          klass.find_each do |record|
            if record.space&.boundary.present?
              skipped += 1
              next
            end

            perform_now(record)
            imported += 1
            sleep 1.1 if Rails.env.production?
          end
        end

        { imported:, skipped: }
      end

      def perform(geographic_record, force_refresh: false)
        return if geographic_record.space&.boundary.present? && !force_refresh

        data = fetch_polygon_data(geographic_record)
        return unless data&.dig('geojson')

        geometry = parse_geometry(data['geojson'])
        return unless geometry

        save_boundary(geographic_record, geometry, data)
      end

      private

      def fetch_polygon_data(record)
        Geocoder.search(record.to_s, params: { polygon_geojson: 1 }).first&.data
      end

      def parse_geometry(geojson_hash)
        RGeo::GeoJSON.decode(geojson_hash, geo_factory: rgeo_factory)
      end

      def save_boundary(record, geometry, data)
        space = record.space
        space.boundary = to_multi_polygon(geometry)
        space.metadata = space.metadata.merge(
          'boundary_source' => {
            'provider' => 'nominatim',
            'osm_type' => data['osm_type'],
            'osm_id' => data['osm_id'],
            'fetched_at' => Time.current.iso8601
          }
        )
        space.save!
      end

      def to_multi_polygon(geometry)
        return geometry if geometry.is_a?(RGeo::Feature::MultiPolygon)
        return rgeo_factory.multi_polygon([geometry]) if geometry.is_a?(RGeo::Feature::Polygon)

        nil
      end

      def rgeo_factory
        RGeo::Geographic.spherical_factory(srid: 4326)
      end
    end
  end
end
