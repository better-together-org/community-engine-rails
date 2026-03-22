# frozen_string_literal: true

# app/policies/better_together/navigation_area_policy.rb

module BetterTogether
  class NavigationAreaPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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

    private

    def platform_navigation_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
