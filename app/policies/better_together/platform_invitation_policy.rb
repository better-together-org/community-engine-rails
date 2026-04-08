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

    private

    def can_manage_platform_members?
      return true if permitted_to?('manage_platform_members') || permitted_to?('manage_platform_roles')

      platform = record.try(:invitable)
      permitted_to?('manage_platform_members', platform) ||
        permitted_to?('manage_platform_roles', platform)
    end

    # Scope class for filtering platform invitations based on user permissions
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user.present?

        scope.where(invitable_id: manageable_platform_ids)
      end

      private

      def manageable_platform_ids
        BetterTogether::PersonPlatformMembership
          .joins(role: { role_resource_permissions: :resource_permission })
          .where(member_id: agent.id)
          .where(better_together_resource_permissions: { identifier: %w[manage_platform_members manage_platform_roles] })
          .select(:joinable_id)
      end
    end
  end
end
