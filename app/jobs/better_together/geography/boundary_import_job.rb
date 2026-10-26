# frozen_string_literal: true

require 'rgeo-geojson'

module BetterTogether
  module Geography
    # One-time/admin-triggered import of a boundary polygon for a single
    # Continent/Country/State/Region/Settlement record, from the same Nominatim/Geocoder
    # backend already used for point geocoding. What to fetch and how (exact OSM id first, then a
    # context-aware name search, simplified polygons) lives in BoundaryFetcher.
    #
    # Never runs on a live request path — always dispatched from
    # `better_together:geography:import_boundaries` (see lib/tasks), which throttles calls
    # serially to respect Nominatim's usage policy. Idempotent: skips records that already
    # have a boundary unless force_refresh is true.
    # rubocop:disable Metrics/ClassLength
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
      # levels: lowercase class names ("settlement"), identifiers: record identifiers, force: refetch records that
      # already have a boundary (or are remembered as having none), dry_run: only list what would be fetched.
      def self.import_all_missing(levels: nil, identifiers: nil, force: false, dry_run: false, threshold: nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        summary = { imported: 0, skipped: 0, skipped_known_missing: 0, unsupported: 0, failed: 0, planned: [] }

        levels_for(levels).each do |klass|
          scope = identifiers.present? ? klass.where(identifier: identifiers) : klass.all
          scope.find_each do |record|
            next if skip?(record, force:, summary:)

            if dry_run
              summary[:planned] << "#{klass.name.demodulize.downcase}/#{record.identifier}"
              next
            end

            tally(summary, perform_with_retries(record, force_refresh: force, threshold:))
            sleep 1.1 if Rails.env.production?
          end
        end

        summary
      end

      def self.levels_for(levels)
        return HIERARCHY_LEVELS if levels.blank?

        wanted = Array(levels).map { |level| level.to_s.downcase }
        HIERARCHY_LEVELS.select { |klass| wanted.include?(klass.name.demodulize.downcase) }
      end

      def self.skip?(record, force:, summary:)
        return false if force

        if record.space&.boundary.present?
          summary[:skipped] += 1
        elsif known_missing?(record)
          summary[:skipped_known_missing] += 1
        else
          return false
        end
        true
      end

      # A previous run found no polygon for this record (Nominatim has only a point for it), recorded on the space.
      def self.known_missing?(record)
        record.space&.metadata.to_h.dig('boundary_source', 'status') == 'no_polygon'
      end

      # perform_with_retries propagates #perform's own return value on a clean
      # (non-exception) path: true when a boundary was actually saved, nil when
      # every intermediate step (no data, unparseable geometry, unsupported
      # geometry type) chose not to save one - distinct from `false`, which
      # perform_with_retries returns only after exhausting real retries on a
      # raised exception.
      def self.tally(summary, outcome)
        case outcome
        when true then summary[:imported] += 1
        when false then summary[:failed] += 1
        else summary[:unsupported] += 1
        end
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
      def self.perform_with_retries(record, attempts: MAX_ATTEMPTS, **) # rubocop:todo Metrics/MethodLength
        attempt = 0
        begin
          attempt += 1
          perform_now(record, **)
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

      def perform(geographic_record, force_refresh: false, threshold: nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        return if geographic_record.space&.boundary.present? && !force_refresh

        fetched = BoundaryFetcher.call(geographic_record, threshold:)
        return remember_missing(geographic_record, fetched.reason) unless fetched.data

        geometry = parse_geometry(fetched.data['geojson'])
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

        save_boundary(geographic_record, multi_polygon, fetched)
      end

      private

      def parse_geometry(geojson_hash)
        RGeo::GeoJSON.decode(geojson_hash, geo_factory: rgeo_factory)
      end

      def save_boundary(record, multi_polygon, fetched)
        space = record.space
        space.boundary = multi_polygon
        space.metadata = space.metadata.merge(
          'boundary_source' => {
            'provider' => 'nominatim',
            'osm_type' => fetched.data['osm_type'],
            'osm_id' => fetched.data['osm_id'],
            'via' => fetched.via.to_s,
            'fetched_at' => Time.current.iso8601
          }
        )
        space.save!
      end

      # Nominatim answered but has no polygon for this record (a point, or nothing): remember it on the space so
      # later runs do not ask again. Skipped when the space was never saved (no coordinates yet); a forced run
      # clears it. Returns nil, the "nothing saved" outcome.
      def remember_missing(record, reason)
        space = record.space
        return unless space&.persisted?

        space.update!(metadata: space.metadata.merge(
          'boundary_source' => { 'provider' => 'nominatim', 'status' => 'no_polygon', 'reason' => reason.to_s,
                                 'checked_at' => Time.current.iso8601 }
        ))
        nil
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
    # rubocop:enable Metrics/ClassLength
  end
end
