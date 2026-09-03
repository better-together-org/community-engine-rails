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
      discard_on ActiveJob::DeserializationError

      MAX_ATTEMPTS = 3

      # Broadest-to-narrowest — the reverse of Locatable::Many::LEVELS (which is keyed
      # narrowest-to-broadest for its resolution-order use there). Derived rather than
      # hand-duplicated so the two can't silently drift apart on a future hierarchy
      # level addition; order isn't load-bearing here (each level imports fully
      # independently) but broadest-first is a sensible human-facing progression.
      HIERARCHY_LEVELS = BetterTogether::Geography::Locatable::Many::LEVELS.values.reverse.freeze

      # Orchestrates a full run across every hierarchy level for
      # `better_together:geography:import_boundaries` — perform_now in a straight serial
      # loop, deliberately NOT perform_later, so only one Nominatim polygon_geojson request
      # is ever in flight regardless of Sidekiq concurrency. Retries happen in-process
      # (perform_with_retries below), never via ActiveJob's queue-based retry_on — that
      # would enqueue a real background-worker retry regardless of this loop's own
      # perform_now calls, letting a retried record's request run concurrently with this
      # loop's next one and breaking the "only one in flight" guarantee.
      def self.import_all_missing # rubocop:todo Metrics/MethodLength
        imported = 0
        skipped = 0
        unsupported = 0
        failed = 0

        HIERARCHY_LEVELS.each do |klass|
          klass.find_each do |record|
            if record.space&.boundary.present?
              skipped += 1
              next
            end

            # perform_with_retries propagates #perform's own return value on a clean
            # (non-exception) path: true when a boundary was actually saved, nil when
            # every intermediate step (no data, unparseable geometry, unsupported
            # geometry type) chose not to save one - distinct from `false`, which
            # perform_with_retries returns only after exhausting real retries on a
            # raised exception. Without this distinction, an unsupported-geometry
            # record was previously counted as `imported` even though no boundary was
            # ever saved, and got silently re-fetched and re-skipped forever with no
            # visible signal.
            case perform_with_retries(record)
            when true then imported += 1
            when false then failed += 1
            else unsupported += 1
            end
            sleep 1.1 if Rails.env.production?
          end
        end

        { imported:, skipped:, unsupported:, failed: }
      end

      # Retries a transient failure (network timeout, 5xx, parse error) up to
      # MAX_ATTEMPTS times in-process with exponential backoff, then logs and gives up
      # rather than raising — one bad record shouldn't abort the rest of the batch.
      #
      # Deliberately NOT ActiveJob's retry_on: that re-enqueues asynchronously
      # regardless of whether the original call was perform_now/perform_later, which
      # would let a retried record's request run concurrently with
      # .import_all_missing's next serial call, breaking the "only one Nominatim
      # request in flight" guarantee documented on that method above.
      def self.perform_with_retries(record, attempts: MAX_ATTEMPTS) # rubocop:todo Metrics/MethodLength
        attempt = 0
        begin
          attempt += 1
          perform_now(record)
        rescue StandardError => e
          if attempt < attempts
            sleep(2**attempt)
            retry
          end

          Rails.logger.warn(
            "BoundaryImportJob: giving up on #{record.class.name}##{record.id} " \
            "after #{attempts} attempts: #{e.message}"
          )
          false
        end
      end

      def perform(geographic_record, force_refresh: false) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        return if geographic_record.space&.boundary.present? && !force_refresh

        data = fetch_polygon_data(geographic_record)
        return unless data&.dig('geojson')

        geometry = parse_geometry(data['geojson'])
        return unless geometry

        multi_polygon = to_multi_polygon(geometry)
        if multi_polygon.nil?
          Rails.logger.warn(
            "BoundaryImportJob: #{geographic_record.class.name}##{geographic_record.id} " \
            "returned an unsupported geometry type (#{geometry.class.name}) - skipping " \
            'rather than saving a nil boundary'
          )
          return
        end

        save_boundary(geographic_record, multi_polygon, data)
      end

      private

      def fetch_polygon_data(record)
        Geocoder.search(record.to_s, params: { polygon_geojson: 1 }).first&.data
      end

      def parse_geometry(geojson_hash)
        RGeo::GeoJSON.decode(geojson_hash, geo_factory: rgeo_factory)
      end

      def save_boundary(record, multi_polygon, data)
        space = record.space
        space.boundary = multi_polygon
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
