# frozen_string_literal: true

module BetterTogether
  module Geography
    class GeocodingJob < ApplicationJob # rubocop:todo Style/Documentation
      queue_as :geocoding
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      discard_on ActiveJob::DeserializationError
      discard_on Geocoder::ResponseParseError

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
