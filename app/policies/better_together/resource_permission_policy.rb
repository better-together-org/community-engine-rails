# frozen_string_literal: true

# app/policies/better_together/resource_permission_policy.rb

module BetterTogether
  class ResourcePermissionPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && can_manage_any_roles?
    end

    def show?
      user.present? && can_manage_permission_resource_type?
    end

    def create?
      user.present? && can_manage_permission_resource_type?
    end

    def new?
      create?
    end

    def update?
      user.present? && can_manage_permission_resource_type?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && can_manage_permission_resource_type? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present?

        return scope.positioned if can_manage_any_roles?

        scope.none
      end

      private

      def can_manage_any_roles?
        permitted_to?('manage_platform_roles') || permitted_to?('manage_community_roles')
      end
    end

    private

    def can_manage_permission_resource_type?
      # When called with the class (e.g. policy(ResourcePermission).create?), fall back to any-role check
      return can_manage_any_roles? if record.is_a?(Class)

      case record.resource_type
      when 'BetterTogether::Platform'
        permitted_to?('manage_platform_roles')
      when 'BetterTogether::Community'
        permitted_to?('manage_community_roles')
      else
        can_manage_any_roles?
      end
    end

    def can_manage_any_roles?
      permitted_to?('manage_platform_roles') || permitted_to?('manage_community_roles')
    end
  end
end
