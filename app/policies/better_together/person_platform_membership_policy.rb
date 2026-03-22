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

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
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
