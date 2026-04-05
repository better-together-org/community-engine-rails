# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class CalendarPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && (can_view_calendar? || platform_calendar_manager?)
    end

    def feed?
      # Feed access is controlled by the controller's token validation
      # or standard show permissions for authenticated users
      show?
    end

    def update?
      user.present? && (record.creator == agent || platform_calendar_manager?)
    end

    def create?
      user.present? && platform_calendar_manager?
    end

    private

    def platform_calendar_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end

    def can_view_calendar?
      return true if public_or_signed_in_community?(record)
      return true if record.creator == agent

      false
    end

    def same_community?
      agent&.community_id == record.community_id
    end

    # Filtering and sorting for calendars according to permissions and context
    class Scope < ApplicationPolicy::Scope
    end
  end
end
