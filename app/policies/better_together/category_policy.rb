# frozen_string_literal: true

module BetterTogether
  class CategoryPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    def index?
      platform_taxonomy_manager?
    end

    def create?
      platform_taxonomy_manager?
    end

    def update?
      platform_taxonomy_manager?
    end

    def show?
      platform_taxonomy_manager?
    end

    private

    def platform_taxonomy_manager?(target = record)
      platform = (target.respond_to?(:platform) ? target.platform : nil) || current_platform
      permitted_to?('manage_platform_settings', platform) || permitted_to?('manage_platform', platform)
    end
  end
end
