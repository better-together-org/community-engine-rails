# frozen_string_literal: true

module BetterTogether
  # Policy for API-managed robot records.
  class RobotPolicy < ApplicationPolicy
    def index?
      platform_manager?
    end

    def show?
      platform_manager?
    end

    def create?
      platform_manager?
    end

    def update?
      platform_manager?
    end

    def destroy?
      platform_manager?
    end

    # Scope for robot records manageable through the API.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user&.person&.permitted_to?('manage_platform')

        scope.all
      end
    end

    private

    def platform_manager?
      permitted_to?('manage_platform')
    end
  end
end
