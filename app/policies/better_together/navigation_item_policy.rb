# frozen_string_literal: true

# app/policies/better_together/navigation_item_policy.rb

module BetterTogether
  class NavigationItemPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      true
    end

    def show?
      true
    end

    def create?
      permitted_to?('manage_platform')
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
        if user.present?
          scope.all
        else
          scope.visible.top_level.ordered.includes(:children)
        end
      end
    end
  end
end
