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

    def platform_taxonomy_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
