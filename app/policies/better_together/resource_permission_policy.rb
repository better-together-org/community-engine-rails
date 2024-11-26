# frozen_string_literal: true

# app/policies/better_together/resource_permission_policy.rb

module BetterTogether
  class ResourcePermissionPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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
      false
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        scope.positioned
      end
    end
  end
end
