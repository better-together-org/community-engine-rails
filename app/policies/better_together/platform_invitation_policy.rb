# frozen_string_literal: true

module BetterTogether
  class PlatformInvitationPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      user.present?
    end

    def destroy?
      user.present?
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end
  end
end
