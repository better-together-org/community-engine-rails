# frozen_string_literal: true

module BetterTogether
  module Geography
    class GeocodingJob < ApplicationJob # rubocop:todo Style/Documentation
      queue_as :geocoding

      def perform(geocodable)
        geocodable.geocode
        geocodable.save
      end
    end
  end
end
