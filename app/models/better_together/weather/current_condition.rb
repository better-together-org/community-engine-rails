# frozen_string_literal: true

module BetterTogether
  module Weather
    # The latest normalised conditions for a location (one row per location).
    class CurrentCondition < ApplicationRecord
      STALE_AFTER = 3.hours

      belongs_to :location, class_name: 'BetterTogether::Weather::Location', inverse_of: :current_condition

      validates :fetched_at, presence: true

      def stale?(now: Time.current)
        (observed_at || fetched_at) < now - STALE_AFTER
      end
    end
  end
end
