# frozen_string_literal: true

module BetterTogether
  module Weather
    # Refreshes current conditions and forecasts for one location.
    class RefreshLocationJob < ApplicationJob
      queue_as :weather

      def perform(location_id)
        location = Location.enabled.find_by(id: location_id)
        RefreshLocation.call(location) if location
      end
    end
  end
end
