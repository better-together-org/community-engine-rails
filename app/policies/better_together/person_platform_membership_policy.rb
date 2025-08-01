# frozen_string_literal: true

module BetterTogether
  class PersonPlatformMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && permitted_to?('update_platform')
    end

    def create?
      user.present? && permitted_to?('update_platform')
    end

    def edit?
      user.present? && permitted_to?('update_platform')
    end

    def destroy?
      user.present? && !me? && permitted_to?('update_platform') && !record.member.permitted_to?('manage_platform')
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end

    protected

    def me?
      record.member == agent
    end
  end
end
