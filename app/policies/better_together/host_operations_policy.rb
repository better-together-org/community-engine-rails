# frozen_string_literal: true

module BetterTogether
  # Policy for platform operations tools dashboard access.
  # Operations tools (Sidekiq, API docs, MCP, OAuth) are restricted to
  # platform managers — the same gate as the host dashboard.
  class HostOperationsPolicy < ApplicationPolicy
    def index?
      return false unless user

      platform = Platform.find_by(host: true)
      user.permitted_to?(:manage_platform_settings, platform) ||
        user.permitted_to?(:manage_platform, platform)
    end
  end
end
