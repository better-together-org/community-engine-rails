# frozen_string_literal: true

module BetterTogether
  # Authorization policy for platform invitations
  # Defines who can view, create, update, and manage platform invitations
  # Note: Platform invitations use a different system than community/event invitations
  class PlatformInvitationPolicy < ApplicationPolicy
    def index?
      user.present? && permitted_to?('manage_platform')
    end

    def create?
      user.present? && permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.status_pending? && (record.inviter.id == agent.id || permitted_to?('manage_platform'))
    end

    def resend?
      user.present? && record.status_pending? && (record.inviter.id == agent.id || permitted_to?('manage_platform'))
    end

    # Scope class for filtering platform invitations based on user permissions
    class Scope < ApplicationPolicy::Scope
      def resolve
        results = scope
        results = scope.where(inviter: agent) unless permitted_to?('manage_platform')

        results
      end
    end
  end
end
