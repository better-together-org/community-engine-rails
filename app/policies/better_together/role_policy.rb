# frozen_string_literal: true

# app/policies/better_together/role_policy.rb

module BetterTogether
  class RolePolicy < ApplicationPolicy
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
      user.present?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.positioned
      end
    end
  end
end
