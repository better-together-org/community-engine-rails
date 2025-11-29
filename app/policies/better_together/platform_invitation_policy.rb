# frozen_string_literal: true

module BetterTogether
  class PlatformInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        results = scope
        results = scope.where(inviter: agent) unless permitted_to?('manage_platform')

        results
      end
    end
  end
end
