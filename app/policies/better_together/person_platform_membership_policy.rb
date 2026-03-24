# frozen_string_literal: true

module BetterTogether
  class PersonPlatformMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && can_manage_platform_members?
    end

    def show?
      user.present? && (me? || can_manage_platform_members?)
    end

    def new?
      user.present? && can_manage_platform_members?
    end

    def create?
      user.present? && can_manage_platform_members?
    end

    def edit?
      user.present? && can_manage_platform_members?
    end

    def update?
      user.present? && can_manage_platform_members?
    end

    def destroy?
      user.present? && !me? && can_manage_platform_members? &&
        !record.member.permitted_to?('manage_platform_roles', record.joinable)
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless agent

        own_memberships.or(manageable_memberships).distinct
      end

      private

      def own_memberships
        scope.where(member_id: agent.id)
      end

      def manageable_memberships
        scope.where(joinable_id: manageable_platform_ids)
      end

      def manageable_platform_ids
        return BetterTogether::Platform.select(:id) if permitted_to?('manage_platform_members') || permitted_to?('manage_platform_roles')

        BetterTogether::PersonPlatformMembership
          .joins(role: { role_resource_permissions: :resource_permission })
          .where(member_id: agent.id)
          .where(better_together_resource_permissions: { identifier: %w[manage_platform_members manage_platform_roles] })
          .select(:joinable_id)
      end
    end

    protected

    def can_manage_platform_members?
      return true if permitted_to?('manage_platform_members') || permitted_to?('manage_platform_roles')

      platform = record.try(:joinable)

      permitted_to?('manage_platform_members', platform) ||
        permitted_to?('manage_platform_roles', platform)
    end

    def me?
      record.member == agent
    end
  end
end
