# frozen_string_literal: true

module BetterTogether
  # Policy for host-admin managed platform domains.
  # Follows the existing /host management contract, scoped per-platform so a
  # steward of one platform cannot manage another platform's domains.
  class PlatformDomainPolicy < ApplicationPolicy
    include PlatformGrantAuthority

    # Association scope an operator needs to administer a managed platform's domains.
    OPERATOR_SCOPE = 'manage_settings'

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

    # The governing operator may activate domains and use any hostname; a steward may only request.
    def operator?
      grant_authority_for?(target_platform, scope: OPERATOR_SCOPE)
    end

    private

    def target_platform
      record.respond_to?(:platform) ? record.platform : nil
    end

    def platform_manager_for_target_platform?
      return false unless agent.present? && target_platform.present?

      agent.permitted_to?('manage_platform', target_platform) ||
        agent.permitted_to?('manage_platform_settings', target_platform) ||
        operator?
    end
  end
end
