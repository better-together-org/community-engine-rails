# frozen_string_literal: true

module BetterTogether
  # Settlement weather: sources, tracked locations and the stored readings
  # (current conditions, forecasts, observation history) that pages read from.
  module Weather
    def self.table_name_prefix
      'better_together_weather_'
    end
  end
end
