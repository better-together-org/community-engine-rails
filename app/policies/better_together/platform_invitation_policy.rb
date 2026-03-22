# frozen_string_literal: true

module BetterTogether
  # Authorization policy for platform invitations
  # Defines who can view, create, update, and manage platform invitations
  # Note: Platform invitations use a different system than community/event invitations
  class PlatformInvitationPolicy < ApplicationPolicy
    def index?
      user.present? && can_manage_platform_members?
    end

    def create?
      user.present? && can_manage_platform_members?
    end

    def destroy?
      user.present? && record.status_pending? && (record.inviter.id == agent.id || can_manage_platform_members?)
    end

    def resend?
      user.present? && record.status_pending? && (record.inviter.id == agent.id || can_manage_platform_members?)
    end

    # Scope class for filtering platform invitations based on user permissions
    class Scope < ApplicationPolicy::Scope
      def resolve
        results = scope
        results = scope.where(inviter: agent) unless can_manage_platform_members?

        results
      end

      private

      def can_manage_platform_members?
        # Global check first (platform manager role grants this without needing a specific record)
        return true if permitted_to?('manage_platform_members') || permitted_to?('manage_platform_roles')

        platform = scope.first&.invitable

        permitted_to?('manage_platform_members', platform) ||
          permitted_to?('manage_platform_roles', platform)
      end
    end

    private

    def can_manage_platform_members?
      return true if permitted_to?('manage_platform_members') || permitted_to?('manage_platform_roles')

      platform = record.try(:invitable)

      permitted_to?('manage_platform_members', platform) ||
        permitted_to?('manage_platform_roles', platform)
    end
  end
end
