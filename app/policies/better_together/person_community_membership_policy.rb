# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < ApplicationPolicy
    def create?
      user.present? && permitted_to?('update_community')
    end

    def edit?
      user.present? && permitted_to?('update_community')
    end

    def destroy?
      user.present? && !me? && permitted_to?('update_community') && !record.member.permitted_to?('manage_platform')
    end

    class Scope < Scope
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
