# frozen_string_literal: true

module BetterTogether
  class PersonBlockPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def new?
      user.present?
    end

    def create?
      # Must be logged in and be the blocker
      return false unless user.present? && record.blocker == agent

      # Must have a valid blocked person
      return false unless record.blocked.present?

      # Cannot block platform managers
      !blocked_user_is_platform_manager?
    end

    def destroy?
      user.present? && record.blocker == agent
    end

    def blocked_user_is_platform_manager?
      return false unless record.blocked

      # Check if the blocked person's user has platform management permissions
      record.blocked.permitted_to?('manage_platform')
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.where(blocker: agent)
      end
    end
  end
end
