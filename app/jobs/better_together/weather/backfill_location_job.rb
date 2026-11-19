# frozen_string_literal: true

module BetterTogether
  module Weather
    # Fills observation gaps for one location from the source's history API.
    class BackfillLocationJob < BaseJob
      def perform(location_id, days = BackfillObservations::DEFAULT_DAYS)
        location = Location.active.find_by(id: location_id)
        BackfillObservations.call(location, days: days) if location
      end
    end
  end
end
