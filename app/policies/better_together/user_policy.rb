# frozen_string_literal: true

module BetterTogether
  class UserPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      can_manage_user_accounts?
    end

    def show?
      user.present? && (record == user || can_manage_user_accounts?)
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      can_manage_user_accounts?
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    def me?
      record === user # rubocop:todo Style/CaseEquality
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        platform = BetterTogether::Current.platform || BetterTogether::Current.host_platform
        return scope.none unless platform

        platform_scope = scope.where(platform_id: platform.id)
        return platform_scope.where(id: user.id) unless permitted_to?('manage_platform_users')

        platform_scope.order(created_at: :desc)
      end
    end
  end
end
