# frozen_string_literal: true

module BetterTogether
  class PersonBlockPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def create?
      user.present? && record.blocker == agent && !record.blocked.permitted_to?('manage_platform')
    end

    def destroy?
      user.present? && record.blocker == agent
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.where(blocker: agent)
      end
    end
  end
end
