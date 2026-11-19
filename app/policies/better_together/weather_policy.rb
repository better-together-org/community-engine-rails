# frozen_string_literal: true

module BetterTogether
  # Host steward access to weather management: the host-wide switch, sources and locations.
  # Only people with manage_platform_settings on the host platform pass; no weather permission exists.
  class WeatherPolicy < ApplicationPolicy
    def index?
      host_steward?
    end

    def show?
      host_steward?
    end

    def update?
      host_steward?
    end

    def toggle?
      update?
    end

    private

    def host_steward?
      host_platform = Current.host_platform
      return false unless agent && host_platform

      agent.permitted_to?('manage_platform_settings', host_platform)
    end
  end
end
