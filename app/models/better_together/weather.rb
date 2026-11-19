# frozen_string_literal: true

module BetterTogether
  # Settlement weather: sources, tracked locations and the stored readings
  # (current conditions, forecasts, observation history) that pages read from.
  module Weather
    SETTING_CACHE_KEY = 'better_together/weather/host_setting_enabled'
    SETTING_CACHE_TTL = 1.minute

    def self.table_name_prefix
      'better_together_weather_'
    end

    # True when the feature is switched on and at least one enabled location of an enabled
    # source exists. The location check is one uncached EXISTS query.
    def self.enabled?
      return false unless feature_enabled?

      Location.enabled.exists?(source_id: Source.enabled.select(:id))
    end

    # The feature switch alone. BETTER_TOGETHER_WEATHER_ENABLED=false is a hard kill switch;
    # otherwise the host platform's weather_enabled setting decides (default on).
    def self.feature_enabled?
      return false if env_forced_off?

      host_setting_enabled?
    end

    def self.env_forced_off?
      !BetterTogether.weather_enabled
    end

    # The host steward's switch, cached briefly. Platform expires the key when it changes.
    def self.host_setting_enabled?
      Rails.cache.fetch(SETTING_CACHE_KEY, expires_in: SETTING_CACHE_TTL) do
        host = Platform.find_by(host: true)
        host.nil? || host.weather_enabled != false
      end
    end

    def self.expire_setting_cache!
      Rails.cache.delete(SETTING_CACHE_KEY)
    end

    # True when stored readings exist, so retention still has work after sources are removed.
    def self.data_stored?
      Observation.exists? || Forecast.exists?
    end
  end
end
