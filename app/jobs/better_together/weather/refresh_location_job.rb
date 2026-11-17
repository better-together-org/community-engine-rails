# frozen_string_literal: true

module BetterTogether
  module Weather
    # Refreshes current conditions and forecasts for one location.
    class RefreshLocationJob < BaseJob
      def perform(location_id)
        location = Location.active.find_by(id: location_id)
        RefreshLocation.call(location) if location
      end
    end
  end
end
