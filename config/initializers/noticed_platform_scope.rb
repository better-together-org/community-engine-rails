# frozen_string_literal: true

# Extend Noticed::Notification to support multi-platform deployments.
#
# Stamps platform_id on every new notification from the current request context
# (set by PlatformContextMiddleware for web/API/MCP requests) or, when the
# notifier runs in a background job without a request context, from the event
# record's own platform_id if it carries one.
#
# The column is nullable so legacy notifications without a platform_id still
# render — the queries fall back to Current.platform = nil (show all).

Rails.application.config.after_initialize do
  Noticed::Notification.class_eval do
    belongs_to :platform,
               class_name: 'BetterTogether::Platform',
               foreign_key: :platform_id,
               optional: true

    before_create :stamp_platform_id

    private

    def stamp_platform_id
      return if platform_id.present?

      self.platform_id =
        BetterTogether::Current.platform&.id ||
        platform_id_from_event_record
    end

    def platform_id_from_event_record
      record = event&.record
      return unless record.respond_to?(:platform_id)

      record.platform_id
    end
  end
end
