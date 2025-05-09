# frozen_string_literal: true

module BetterTogether
  module Geography
    class GeocodingJob < ApplicationJob # rubocop:todo Style/Documentation
      queue_as :geocoding
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      def perform(geocodable)
        coords = geocodable.geocode
        geocodable.save if coords
      end
    end
  end
end
