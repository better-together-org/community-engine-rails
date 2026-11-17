# frozen_string_literal: true

module BetterTogether
  # Settlement weather: sources, tracked locations and the stored readings
  # (current conditions, forecasts, observation history) that pages read from.
  module Weather
    def self.table_name_prefix
      'better_together_weather_'
    end

    # True when the host has weather on and at least one enabled location of an enabled
    # source exists. One EXISTS query, no caching, so removing a source takes effect at once.
    def self.enabled?
      return false unless BetterTogether.weather_enabled

      Location.enabled.exists?(source_id: Source.enabled.select(:id))
    end

    # True when stored readings exist, so retention still has work after sources are removed.
    def self.data_stored?
      Observation.exists? || Forecast.exists?
    end
  end
end
