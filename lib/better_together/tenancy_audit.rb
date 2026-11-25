# frozen_string_literal: true

module BetterTogether
  # Security-relevant tenancy events (identity provider changes, refused cross-platform actions).
  # Emits an ActiveSupport notification subscribers can persist or ship, and a structured log line
  # (Loki/Sentry friendly). Never pass secrets; callers pass ids and flag names only.
  module TenancyAudit
    EVENT = 'audit.better_together'

    module_function

    def record(action, **attributes)
      payload = { action: action.to_s, platform_id: ::Current.platform&.id, at: Time.current.iso8601 }.merge(attributes)
      ActiveSupport::Notifications.instrument(EVENT, payload)
      Rails.logger.info("[tenancy-audit] #{payload.to_json}")
      payload
    end
  end
end
