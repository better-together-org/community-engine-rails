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

    # Gate for the record's attached media (ActiveStorageSecurity#enforce_download_policy!): the same
    # audience as the record itself. Without this method the gate lets any signed-in user through.
    def download?
      show?
    end

    private

    def platform_taxonomy_manager?(target = record)
      platform = (target.respond_to?(:platform) ? target.platform : nil) || current_platform
      permitted_to?('manage_platform_settings', platform) || permitted_to?('manage_platform', platform)
    end
  end
end
