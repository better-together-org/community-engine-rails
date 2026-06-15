# frozen_string_literal: true

module BetterTogether
  class CategoryPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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

    # Categories scoped to the current platform context.
    class Scope < ApplicationPolicy::Scope
      def resolve
        platform = Current.platform || BetterTogether::Platform.find_by(host: true)
        platform ? scope.where(platform_id: platform.id) : scope.none
      end
    end

    private

    def platform_taxonomy_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
