# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      user.present? && can_manage_community_members?
    end

    def edit?
      user.present? && can_manage_community_members?
    end

    def destroy?
      user.present? && !me? && can_manage_community_members? &&
        !record.member.permitted_to?('manage_community_roles', record.joinable)
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end

    protected

    def can_manage_community_members?
      community = record.try(:joinable)

      permitted_to?('manage_community_members', community) ||
        permitted_to?('manage_community_roles', community)
    end

    def me?
      record.member == agent
    end
  end
end
