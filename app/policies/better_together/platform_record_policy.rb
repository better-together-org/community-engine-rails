# frozen_string_literal: true

module BetterTogether
  # Base Pundit policy for models inheriting PlatformRecord.
  # Provides current_platform and record_on_current_platform? helpers at the
  # policy level, and a Scope whose default resolve returns records belonging
  # to the current platform. Subclasses that need additional filtering override
  # resolve and call platform_scoped as their starting point.
  class PlatformRecordPolicy < ApplicationPolicy
    def current_platform
      Current.platform || Current.host_platform
    end

    def record_on_current_platform?
      current_platform.present? && record.platform_id == current_platform.id
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        platform_scoped
      end

      protected

      # Returns scope filtered to the current platform, or scope.none when no
      # platform context exists. Accepts an optional base so callers that have
      # already chained (e.g. with_translations) can pass their modified scope.
      def platform_scoped(base = scope)
        platform = current_platform
        platform ? base.where(platform_id: platform.id) : base.none
      end

      def current_platform
        Current.platform || Current.host_platform
      end
    end
  end
end
