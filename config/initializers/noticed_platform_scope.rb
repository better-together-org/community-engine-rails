# frozen_string_literal: true

# Extend Noticed::Notification to support multi-platform deployments.
#
# Stamps platform_id on every new notification from the current request context
# (set by PlatformContextMiddleware for web/API/MCP requests) or, when the
# notifier runs in a background job without a request context, from the event
# record's own platform_id if it carries one, falling back to the host
# platform when neither is available (matches PlatformScoped's own 3-tier
# fallback so background-delivered notifications without a request context
# or a platform-bearing record don't end up permanently unattributed).
#
# The column is nullable so legacy notifications without a platform_id still
# render — the queries fall back to Current.platform = nil (show all).

# to_prepare (not after_initialize) so this survives Zeitwerk class reloading in
# development/test — after_initialize's class_eval only ran once at boot, and any
# later autoload of Noticed::Notification (e.g. on first reference within a test
# process, or after a dev-mode code reload) replaced it with an unpatched
# constant, silently no-op'ing this entire mechanism outside of eager-loaded
# production boots.
Rails.application.config.to_prepare do
  Noticed::Notification.class_eval do
    belongs_to :platform,
               class_name: 'BetterTogether::Platform',
               foreign_key: :platform_id,
               optional: true

    before_create :stamp_platform_id unless _create_callbacks.any? { |cb| cb.filter == :stamp_platform_id }

    private

    def stamp_platform_id
      return if platform_id.present?

      self.platform_id =
        Current.platform&.id ||
        platform_id_from_event_record ||
        BetterTogether::Platform.find_by(host: true)&.id
    end

    def platform_id_from_event_record
      record = event&.record
      return unless record.respond_to?(:platform_id)

      record.platform_id
    end
  end
end
