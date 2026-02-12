# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class RolePolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      permitted_to?('manage_platform')
    end

    def edit?
      update?
    end

    def destroy?
      permitted_to?('manage_platform') && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        scope.positioned
      end
    end
  end
end
