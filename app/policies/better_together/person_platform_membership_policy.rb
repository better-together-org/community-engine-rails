# frozen_string_literal: true

module BetterTogether
  class PersonPlatformMembershipPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && permitted_to?('update_platform')
    end

    def show?
      user.present? && (me? || permitted_to?('update_platform'))
    end

    def new?
      user.present? && permitted_to?('update_platform')
    end

    def create?
      user.present? && permitted_to?('update_platform')
    end

    def edit?
      user.present? && permitted_to?('update_platform')
    end

    def update?
      user.present? && permitted_to?('update_platform')
    end

    def destroy?
      user.present? && !me? && permitted_to?('update_platform') && !record.member.permitted_to?('manage_platform')
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

    def me?
      record.member == agent
    end
  end
end
