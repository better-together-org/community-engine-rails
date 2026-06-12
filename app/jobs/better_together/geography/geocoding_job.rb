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
        geocodable.save if coords
      rescue ActiveRecord::RecordNotFound
        # Record was deleted before the job could run
        Rails.logger.info 'GeocodingJob: Record no longer exists, skipping geocoding operation'
      end
    end
  end
end
