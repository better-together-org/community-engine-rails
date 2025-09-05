# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class CalendarPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && (can_view_calendar? || permitted_to?('manage_platform'))
    end

    def update?
      user.present? && (record.creator == agent || permitted_to?('manage_platform'))
    end

    def create?
      user.present? && permitted_to?('manage_platform')
    end

    private

    def can_view_calendar?
      return true if record.privacy_public?
      return true if record.privacy_community? && same_community?
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
