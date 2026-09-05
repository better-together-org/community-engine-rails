# frozen_string_literal: true

module BetterTogether
  # Base Pundit policy for models inheriting PlatformRecord.
  # Provides current_platform and record_on_current_platform? helpers at the
  # policy level, and a Scope whose default resolve returns records belonging
  # to the current platform. Subclasses that need additional filtering override
  # resolve and call platform_scoped as their starting point.
  class PlatformRecordPolicy < ApplicationPolicy
    def current_platform
      self.class.resolve_current_platform
    end

    def record_on_current_platform?
      current_platform.present? && record.platform_id == current_platform.id
    end

    class << self
      # Some controllers (e.g. EventsController, CommunitiesController) use
      # prepend_before_action to set their resource instance before Pundit
      # authorization runs — in Rails, prepend_before_action jumps ahead of an
      # inherited around_action's setup phase regardless of class hierarchy, so
      # ApplicationController's around_action :with_current_platform_context may
      # not have populated Current.platform / Current.host_platform yet. Falling
      # back to a direct query (same fallback ApplicationHelper#host_platform and
      # EventsController#platform_scoped_event_ignoring_privacy already use)
      # keeps policy scoping correct regardless of callback ordering, instead of
      # silently resolving to scope.none for every request that hits this window.
      def resolve_current_platform
        Current.platform || Current.host_platform || BetterTogether::Platform.find_by(host: true)
      end
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
        PlatformRecordPolicy.resolve_current_platform
      end
    end
  end
end
