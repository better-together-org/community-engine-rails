# frozen_string_literal: true

module BetterTogether
  class ChecklistPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def show?
      # Allow viewing public checklists to everyone, otherwise fall back to update permissions
      record.privacy_public? || update?
    end

    def index?
      # Let policy_scope handle visibility; index access is allowed (scope filters public/private)
      true
    end

    def create?
      permitted_to?('manage_platform')
    end

    def update?
      permitted_to?('manage_platform') || (agent.present? && record.creator == agent)
    end

    def destroy?
      permitted_to?('manage_platform') && !record.protected?
    end

    def completion_status?
      update?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        scope.with_translations
      end
    end
  end
end
