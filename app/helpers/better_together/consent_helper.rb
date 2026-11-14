# frozen_string_literal: true

module BetterTogether
  # Reads the visitor's consent decision and decides which consent controls are needed.
  module ConsentHelper
    # What the platform asks consent for right now; a change here re-asks everyone.
    def consent_policy_version(platform = host_platform)
      request.env['better_together.consent_policy_version'] ||= BetterTogether::Consent.policy_version(platform)
    end

    # The decision in the cookie, or nil when there is none or it was made under an older policy.
    def consent_decision
      @consent_decision ||= begin
        raw = cookies[BetterTogether::Consent::COOKIE]
        BetterTogether::Consent.parse(raw) if BetterTogether::Consent.parse_policy_version(raw) == consent_policy_version
      end
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

    # Optional categories that something on this platform uses (providers, visible cookie policy
    # segments, enabled snippets). The banner and the settings form list only these.
    def consent_categories_in_use(platform = host_platform)
      used = BetterTogether::Consent.categories_in_use(platform)
      if platform.persisted? && platform.snippets_enabled?
        used |= platform.platform_snippets.enabled.where.not(consent_category: 'none').pluck(:consent_category).uniq
      end
      BetterTogether::Consent::CATEGORIES & used
    end

    # Segments that explain a category, for the settings form and the policy page.
    def consent_segments_for(category, platform = host_platform)
      BetterTogether::CookiePolicy.segments_for_category(platform, category)
    end

    # The signed-in person's stored decision, for the settings form.
    def consent_preference_for(person)
      BetterTogether::ConsentPreference.new(person)
    end
  end
end
