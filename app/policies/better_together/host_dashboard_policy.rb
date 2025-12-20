# frozen_string_literal: true

module BetterTogether
  # Policy for host dashboard access control
  class HostDashboardPolicy < ApplicationPolicy
    def show?
      return false unless user

      platform = Platform.find_by(host: true)
      user.permitted_to?(:view_metrics_dashboard, platform) || user.permitted_to?(:manage_platform, platform)
    end
  end
end
