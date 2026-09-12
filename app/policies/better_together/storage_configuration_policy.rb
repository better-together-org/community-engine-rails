# frozen_string_literal: true

module BetterTogether
  # Policy for StorageConfiguration — only platform managers may manage storage configs.
  class StorageConfigurationPolicy < ApplicationPolicy
    def index?
      platform_manager?
    end

    def show?
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

    def activate?
      platform_manager?
    end

    private

    def target_platform
      record.respond_to?(:platform) ? record.platform : nil
    end

    def platform_manager?
      return false unless agent.present? && target_platform.present?

      agent.permitted_to?('manage_platform', target_platform) || agent.permitted_to?('manage_platform_settings', target_platform)
    end
  end
end
