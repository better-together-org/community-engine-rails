# frozen_string_literal: true

module BetterTogether
  # Policy for host-admin managed feature access grants.
  # This surface intentionally follows the existing /host management contract,
  # where host platform managers can administer platform-level operations.
  class FeatureAccessGrantPolicy < ApplicationPolicy
    def index?
      platform_manager_for_target_platform?
    end

    def new?
      platform_manager_for_target_platform?
    end

    def create?
      platform_manager_for_target_platform?
    end

    def edit?
      platform_manager_for_target_platform?
    end

    def update?
      platform_manager_for_target_platform?
    end

    def destroy?
      platform_manager_for_target_platform?
    end

    private

    def target_platform
      record.respond_to?(:platform) ? record.platform : nil
    end

    def platform_manager_for_target_platform?
      return false unless agent.present? && target_platform.present?

      agent.permitted_to?('manage_platform', target_platform) ||
        agent.permitted_to?('manage_platform_settings', target_platform)
    end
  end
end
