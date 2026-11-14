# frozen_string_literal: true

module BetterTogether
  # Policy for the seed catalog admin page — platform managers only, same gate as HostDashboardPolicy.
  class SeedCatalogPolicy < ApplicationPolicy
    def show?
      return false unless user

      platform = Current.host_platform
      user.permitted_to?(:manage_platform_settings, platform) || user.permitted_to?(:manage_platform, platform)
    end
  end
end
