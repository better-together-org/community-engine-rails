# frozen_string_literal: true

module BetterTogether
  # Expires the cached host weather switch (Weather.host_setting_enabled?) when the
  # weather_enabled setting changes, so jobs and pages see the change at once.
  module PlatformWeatherSetting
    extend ActiveSupport::Concern

    included do
      after_commit :expire_weather_setting_cache, if: :saved_change_to_weather_enabled_setting?
    end

    private

    def saved_change_to_weather_enabled_setting?
      return false unless host? && saved_change_to_settings?

      before, after = saved_change_to_settings
      (before || {})['weather_enabled'] != (after || {})['weather_enabled']
    end

    def expire_weather_setting_cache
      BetterTogether::Weather.expire_setting_cache!
    end
  end
end
