# frozen_string_literal: true

# app/policies/better_together/navigation_item_policy.rb

module BetterTogether
  class NavigationItemPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def create?
      user.present?
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
        if user.present?
          scope.all
        else
          scope.visible.top_level.ordered.includes(:children)
        end
      end
    end
  end
end
