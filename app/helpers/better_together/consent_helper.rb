# frozen_string_literal: true

module BetterTogether
  # Reads the visitor's consent decision and decides whether the banner is needed.
  module ConsentHelper
    def consent_decision
      @consent_decision ||= BetterTogether::Consent.parse(cookies[BetterTogether::Consent::COOKIE])
    end

    def consent_granted?(category)
      return true if category.to_s == 'none'

      consent_decision&.fetch(category.to_s, false) || false
    end

    def consent_gated_snippets?(platform)
      platform.persisted? && platform.snippets_enabled? &&
        platform.platform_snippets.enabled.where.not(consent_category: 'none').exists?
    end

    def consent_banner_needed?(platform = host_platform)
      return false unless platform

      consent_gated_snippets?(platform) || BetterTogether::Consent.provider_requires?(platform)
    end
  end
end
