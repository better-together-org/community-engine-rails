# frozen_string_literal: true

module BetterTogether
  # Background jobs screen, its summary panel and the mounted Sidekiq UI. Held through
  # manage_platform_jobs on the host platform only, so a steward of another platform gets nothing.
  class HostJobsPolicy < ApplicationPolicy
    PERMISSION = 'manage_platform_jobs'

    def show?
      return false unless user

      platform = Current.host_platform
      platform.present? && user.permitted_to?(PERMISSION, platform)
    end

    alias summary? show?
    alias sidekiq? show?
  end
end
