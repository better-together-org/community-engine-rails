# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class CalendarPolicy < ApplicationPolicy
    def index?
      user.present? && permitted_to?('manage_platform')
    end

    def show?
      user.present? && (record.creator == agent or permitted_to?('manage_platform'))
    end

    def update?
      user.present? && (record.creator == agent or permitted_to?('manage_platform'))
    end

    def create?
      user.present? && permitted_to?('manage_platform')
    end

    # Filtering and sorting for calendars according to permissions and context
    class Scope < ApplicationPolicy::Scope
    end
  end
end
