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
  end
end
