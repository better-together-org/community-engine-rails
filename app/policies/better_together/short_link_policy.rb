# frozen_string_literal: true

module BetterTogether
  class ShortLinkPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      user.present? && creator_or_manager?
    end

    def create?
      user.present?
    end

    def update?
      user.present? && creator_or_manager?
    end

    def destroy?
      user.present? && creator_or_manager?
    end

    # Scope uses Current.platform only (not host_platform fallback) because
    # short links are always created against a specific platform context and
    # fall outside the scope when no current platform is set.
    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        if permitted_to?('manage_platform')
          scope.where(platform: Current.platform)
        else
          scope.with_creator(agent).for_platform(Current.platform)
        end
      end
    end

    private

    def creator_or_manager?
      (record.creator_id.present? && record.creator == agent) || permitted_to?('manage_platform')
    end

    def permitted_to?(permission)
      agent&.permitted_to?(permission)
    end
  end
end
