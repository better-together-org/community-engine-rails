# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && can_manage_any_community_members?
    end

    def show?
      user.present? && (me? || can_manage_community_members?)
    end

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

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?

        own_memberships.or(manageable_memberships).distinct
      end

      private

      def own_memberships
        scope.where(member_id: agent.id)
      end

      def manageable_memberships
        scope.where(joinable_id: manageable_community_ids)
      end

      def context
        options[:context]
      end

      def manageable_community_ids
        BetterTogether::PersonCommunityMembership
          .joins(role: { role_resource_permissions: :resource_permission })
          .where(member_id: agent.id)
          .where(better_together_resource_permissions: { identifier: %w[manage_community_members manage_community_roles] })
          .select(:joinable_id)
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

    def can_manage_any_community_members?
      return false unless agent

      BetterTogether::PersonCommunityMembership
        .joins(role: { role_resource_permissions: :resource_permission })
        .where(member_id: agent.id)
        .where(better_together_resource_permissions: { identifier: %w[manage_community_members manage_community_roles] })
        .exists?
    end
  end
end
