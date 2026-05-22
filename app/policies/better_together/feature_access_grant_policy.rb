# frozen_string_literal: true

module BetterTogether
  # Policy for platform-managed feature access grants.
  class FeatureAccessGrantPolicy < ApplicationPolicy
    def index?
      platform_manager?
    end

    def new?
      platform_manager?
    end

    def create?
      platform_manager?
    end

    def edit?
      platform_manager?
    end

    def update?
      platform_manager?
    end

    def destroy?
      platform_manager?
    end

    private

    def platform_manager?
      agent&.permitted_to?('manage_platform') || false
    end
  end
end
