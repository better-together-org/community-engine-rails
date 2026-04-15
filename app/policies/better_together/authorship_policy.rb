# frozen_string_literal: true

module BetterTogether
  # Policy for API-managed governed contribution records.
  class AuthorshipPolicy < ApplicationPolicy
    def index?
      platform_content_manager?
    end

    def show?
      platform_content_manager?
    end

    def create?
      platform_content_manager?
    end

    def update?
      platform_content_manager?
    end

    def destroy?
      platform_content_manager?
    end

    # Scope for authorship records that may be managed through the API.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless platform_content_manager?

        scope.all
      end

      private

      def platform_content_manager?
        user&.person&.permitted_to?('manage_platform_settings') ||
          user&.person&.permitted_to?('manage_platform')
      end
    end

    private

    def platform_content_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
