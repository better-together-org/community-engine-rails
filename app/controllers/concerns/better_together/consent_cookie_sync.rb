# frozen_string_literal: true

module BetterTogether
  # Keeps the `bt_consent` cookie in step with the signed-in person's stored decision.
  #
  # While signed in, the stored decision is the source of truth and the cookie is rewritten (expiry
  # refreshed) on every visit so client-side gating and consent-mode code work with no flash.
  #   - stored decision for the current policy version: the cookie is rewritten from it.
  #   - no current stored decision, but the cookie holds a current decision made before sign-in:
  #     it is adopted into the person's record.
  #   - neither: nothing happens and the banner asks.
  # Signing out leaves the cookie alone. Anonymous requests are never touched.
  module ConsentCookieSync
    extend ActiveSupport::Concern

    # Register with `before_action :sync_consent_cookie` after platform and locale are resolved.

    protected

    def write_consent_cookie(decision, policy_version)
      cookies[Consent::COOKIE] = Consent.cookie_options(secure: request.ssl? || Rails.env.production?)
                                        .merge(value: Consent.serialize(decision, policy_version))
    end

    private

    def sync_consent_cookie
      return unless consent_sync_applicable?

      version = helpers.consent_policy_version
      decision = consent_sync_decision(ConsentPreference.new(current_user.person), version)
      write_consent_cookie(decision, version) if decision
    rescue StandardError => e
      # Consent syncing must never take a page down; the banner still works from the cookie.
      Rails.logger.warn("[consent] cookie sync skipped: #{e.class}: #{e.message}")
    end

    def consent_sync_applicable?
      (request.get? || request.head?) && respond_to?(:current_user, true) &&
        current_user&.person.present? && helpers.host_platform.present?
    end

    def consent_sync_decision(preference, version)
      return preference.decision if preference.current?(version)

      raw = cookies[Consent::COOKIE]
      cookie_decision = Consent.parse(raw)
      return unless cookie_decision && Consent.parse_policy_version(raw) == version

      preference.record!(cookie_decision, policy_version: version)
      cookie_decision
    end
  end
end
