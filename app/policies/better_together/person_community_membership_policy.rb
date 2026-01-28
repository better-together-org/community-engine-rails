# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && can_manage_memberships?
    end

    def show?
      user.present? && (me? || can_manage_memberships?)
    end

    def create?
      user.present? && can_manage_memberships?
    end

    def edit?
      update?
    end

    def update?
      user.present? && can_manage_memberships?
    end

    def destroy?
      user.present? && !me? && can_manage_memberships? && !record.member.permitted_to?('manage_platform')
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?
        return scope.all if can_manage_memberships?

        scope.where(member_id: agent.id)
      end

      private

      def can_manage_memberships?
        permitted_to?('update_community') || permitted_to?('manage_platform')
      end
    end

    protected

    def me?
      record.member == agent
    end

    def can_manage_memberships?
      permitted_to?('update_community') || permitted_to?('manage_platform')
    end
  end
end
