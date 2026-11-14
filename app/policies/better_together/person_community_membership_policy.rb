# frozen_string_literal: true

module BetterTogether
  class PersonCommunityMembershipPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && can_manage_any_community_members?
    end

    def show?
      user.present? && (me? || can_manage_community_members?)
    end

    def create?
      user.present? && (can_manage_community_members? || self_service_membership_create?)
    end

    def edit?
      user.present? && can_manage_community_members?
    end

    def destroy?
      user.present? && !me? && can_manage_community_members? &&
        !record.member.permitted_to?('manage_community_roles', record.joinable)
    end

    class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?

        platform_scoped(own_memberships.or(manageable_memberships).distinct)
      end

      private

      def own_memberships
        scope.where(member_id: agent.id)
      end

      def manageable_memberships
        scope.where(joinable_id: manageable_community_ids)
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

    def me?
      record.respond_to?(:member) && record.member == agent
    end

    def can_manage_community_members?
      community = record.try(:joinable)
      return false unless community

      creator_of_community?(community) ||
        permitted_to?('manage_community_members', community) ||
        permitted_to?('manage_community_roles', community)
    end

    def creator_of_community?(community)
      community.respond_to?(:creator_id) && agent.present? && community.creator_id == agent.id
    end

    def self_service_membership_create?
      return false unless me?
      return false unless record.joinable.respond_to?(:supports_self_service_membership?)

      joinable = record.joinable
      joinable.supports_self_service_membership? && (joinable.allows_direct_join? || joinable.membership_requests_enabled?)
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
