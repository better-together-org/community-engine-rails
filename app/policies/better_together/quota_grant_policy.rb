# frozen_string_literal: true

module BetterTogether
  # Policy for host-admin managed quota grant overrides.
  # Mirrors FeatureAccessGrantPolicy's contract exactly: host platform managers
  # administer platform-level operations, here for QuotaGrant instead.
  class QuotaGrantPolicy < ApplicationPolicy
    include PlatformGrantAuthority

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
      grant_authority_for?(target_platform)
    end
  end
end
