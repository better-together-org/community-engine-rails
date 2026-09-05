# frozen_string_literal: true

module BetterTogether
  module Geography
    class GeocodingJob < ApplicationJob # rubocop:todo Style/Documentation
      queue_as :geocoding
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      discard_on ActiveJob::DeserializationError
      discard_on Geocoder::ResponseParseError

      MAX_ATTEMPTS = 3

      # All five hierarchy levels — GeographyBuilder seeds all of them with
      # geocodes_self's auto-scheduling suppressed (see Geospatial::One.without_auto_geocoding),
      # so this is the deliberately-throttled admin path that actually geocodes them
      # afterward. Derived, not hand-duplicated, mirroring
      # BoundaryImportJob::HIERARCHY_LEVELS's own derive-don't-hardcode approach.
      SEEDED_LEVELS = BetterTogether::Geography::Locatable::Many::LEVELS.values.freeze

      # Companion to BoundaryImportJob.import_all_missing — same serial perform_now +
      # sleep(1.1) throttle to respect Nominatim's usage policy, dispatched from
      # `better_together:geography:import_geocodes` (see lib/tasks). perform_now (not
      # perform_later) so only one Nominatim request is ever in flight regardless of
      # Sidekiq concurrency.
      def self.import_all_missing # rubocop:todo Metrics/MethodLength
        imported = 0
        skipped = 0
        failed = 0

        SEEDED_LEVELS.each do |klass|
          klass.find_each do |record|
            if record.geocoded?
              skipped += 1
              next
            end

            if perform_with_retries(record)
              imported += 1
            else
              failed += 1
            end
            sleep 1.1 if Rails.env.production?
          end
        end

        { imported:, skipped:, failed: }
      end

      # Retries a transient failure up to MAX_ATTEMPTS times in-process with
      # exponential backoff, then logs and gives up rather than raising — one bad
      # record shouldn't abort the rest of the batch. Deliberately NOT ActiveJob's
      # retry_on — see BoundaryImportJob.perform_with_retries for why that would break
      # the "only one Nominatim request in flight" guarantee above.
      def self.perform_with_retries(record, attempts: MAX_ATTEMPTS) # rubocop:todo Metrics/MethodLength
        attempt = 0
        begin
          attempt += 1
          perform_now(record)
          true
        rescue StandardError => e
          if attempt < attempts
            sleep(2**attempt)
            retry
          end

          Rails.logger.warn(
            "GeocodingJob: giving up on #{record.class.name}##{record.id} " \
            "after #{attempts} attempts: #{e.message}"
          )
          false
        end
      end

      def perform(geocodable)
        coords = geocodable.geocode
        return unless coords

        stash_raw_geocode_result(geocodable)
        geocodable.save

        geocodable.resolve_geographic_hierarchy! if geocodable.respond_to?(:resolve_geographic_hierarchy!)
      rescue ActiveRecord::RecordNotFound
        # Record was deleted before the job could run
        Rails.logger.info 'GeocodingJob: Record no longer exists, skipping geocoding operation'
      end

      private

      # Geocoder's #geocode only returns coordinates, not the full raw provider result. This
      # re-queries (a cache hit, per config/initializers/geocoder.rb's Rails.cache-backed
      # cache store) to capture ISO country_code/etc. for HierarchyResolutionJob's fallback.
      def stash_raw_geocode_result(geocodable)
        return unless geocodable.respond_to?(:geocoding_string) && geocodable.respond_to?(:space)

        result = Geocoder.search(geocodable.geocoding_string).first
        return unless result

        geocodable.space.metadata = geocodable.space.metadata.merge('geocode' => result.data)
      end
    end
  end
end
