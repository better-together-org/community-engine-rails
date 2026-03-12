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
      platform_navigation_manager?
    end

    def new?
      create?
    end

    def update?
      platform_navigation_manager?
    end

    def edit?
      update?
    end

    def destroy?
      platform_navigation_manager? && !record.protected?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        if platform_navigation_manager?
          scope.all
        else
          scope.visible.top_level.ordered.includes(:children).select { |item| item.visible_to?(user) }
        end
      end

      private

      def platform_navigation_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end

    private

    def platform_navigation_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
