# frozen_string_literal: true

module BetterTogether
  class PlatformInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      user.present? && permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.status_pending? && permitted_to?('manage_platform')
    end

    def resend?
      user.present? && record.status_pending? && permitted_to?('manage_platform')
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end
  end
end
