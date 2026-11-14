# frozen_string_literal: true

module BetterTogether
  # Policy for host dashboard access control
  class HostDashboardPolicy < ApplicationPolicy
    def show?
      return false unless user

      platform = Current.host_platform
      user.permitted_to?(:manage_platform_settings, platform) || user.permitted_to?(:manage_platform, platform)
    end
  end
end
