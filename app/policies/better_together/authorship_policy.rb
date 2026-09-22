# frozen_string_literal: true

module BetterTogether
  # Policy for API-managed governed contribution records.
  class AuthorshipPolicy < PlatformRecordPolicy
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
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return scope.none unless platform_content_manager?

        platform_scoped
      end

      private

      def platform_content_manager?
        user&.person&.permitted_to?('manage_platform_settings', current_platform) ||
          user&.person&.permitted_to?('manage_platform', current_platform)
      end
    end

    private

    def platform_content_manager?(target = record)
      platform = (target.respond_to?(:platform) ? target.platform : nil) || current_platform
      permitted_to?('manage_platform_settings', platform) || permitted_to?('manage_platform', platform)
    end
  end
end
