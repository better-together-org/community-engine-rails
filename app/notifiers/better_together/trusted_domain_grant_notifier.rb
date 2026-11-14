# frozen_string_literal: true

module BetterTogether
  # Tells platform stewards that a trusted domain created an account or granted membership (or hit its limit).
  class TrustedDomainGrantNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    validates :record, presence: true

    def trusted_domain_event
      record
    end

    def title
      I18n.with_locale(locale) do
        I18n.t("better_together.notifications.trusted_domain_grant.#{key_for_event}.title",
               domain: trusted_domain_event.domain)
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t("better_together.notifications.trusted_domain_grant.#{key_for_event}.body",
               domain: trusted_domain_event.domain, role: trusted_domain_event.role_identifier.to_s.humanize,
               person: trusted_domain_event.subject&.name.to_s)
      end
    end

    def build_message(_notification)
      { title:, body:, url: }
    end

    def url
      BetterTogether::Engine.routes.url_helpers.platform_platform_trusted_domains_path(
        trusted_domain_event.platform, locale:
      )
    end

    notification_methods do
      delegate :title, :body, :url, to: :event
    end

    private

    def key_for_event
      trusted_domain_event.event_type == 'grant_rate_limited' ? 'rate_limited' : 'granted'
    end
  end
end
