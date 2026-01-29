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

        # Check if we have a community context (viewing community members)
        if context && context[:community_id].present?
          return scope.none unless can_view_community_members?

          return scope.where(joinable_id: context[:community_id], joinable_type: 'BetterTogether::Community')
        end

        # Check if we have a person context (viewing person's memberships)
        if context && context[:person_id].present?
          # Users can view their own memberships, platform managers can view any
          return scope.none unless context[:person_id] == agent.id.to_s || can_manage_memberships?

          return scope.where(member_id: context[:person_id])
        end

        # Default: show user's own memberships
        return scope.all if can_manage_memberships?

        scope.where(member_id: agent.id)
      end

      private

      def can_view_community_members?
        # Anyone can view public community members (filtered by community privacy in separate concern)
        # Platform managers and community organizers can view all members
        can_manage_memberships?
      end

      def can_manage_memberships?
        permitted_to?('update_community') || permitted_to?('manage_platform')
      end

      def context
        @context ||= options[:context]
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
