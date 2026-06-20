# frozen_string_literal: true

module BetterTogether
  # Policy for OauthApplication — platform managers can manage all applications.
  # Owners can view/manage their own applications.
  class OauthApplicationPolicy < PlatformRecordPolicy
    def index?
      developer_settings_enabled? && (platform_manager? || user&.person.present?)
    end

    def show?
      developer_settings_enabled? && (platform_manager? || owner?)
    end

    def create?
      developer_settings_enabled? && (platform_manager? || user&.person.present?)
    end

    def update?
      developer_settings_enabled? && (platform_manager? || owner?)
    end

    def destroy?
      developer_settings_enabled? && (platform_manager? || owner?)
    end

    private

    def developer_settings_enabled?
      feature_enabled?('developer_settings')
    end

    def owner?
      return false unless user&.person

      record.respond_to?(:owner_id) && record.owner_id == user.person.id
    end

    def platform_manager?
      user&.person&.permitted_to?('manage_platform')
    end

    # Scope: platform managers see all, others see their own
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return scope.none unless feature_enabled?('developer_settings')
        return platform_scoped if platform_manager?
        return platform_scoped.where(owner: user.person) if user&.person

        scope.none
      end

      private

      def platform_manager?
        user&.person&.permitted_to?('manage_platform')
      end
    end
  end
end
