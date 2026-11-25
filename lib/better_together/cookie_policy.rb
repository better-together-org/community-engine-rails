# frozen_string_literal: true

require 'date'
require 'digest'
require 'better_together/cookie_policy/resolution'

# Better Together engine namespace.
module BetterTogether
  # Registry of the cookies and browser storage a platform uses, so the cookie policy page and the
  # consent settings describe them without anyone editing the policy text. Community Engine
  # registers its essential cookies; gems and host apps register theirs:
  #
  #   BetterTogether.register_cookie_policy_segment(
  #     :google_analytics, category: :analytics,
  #     title: 'Google Analytics', description: 'Counts visits so we can improve the site.',
  #     cookies: ->(platform) { [{ name: '_ga', purpose: 'Distinguishes visitors', duration: '2 years',
  #                                provider: 'Google', party: :third }] },
  #     privacy_url: 'https://policies.google.com/privacy', updated_on: Date.new(2026, 11, 14),
  #     if: ->(platform) { measurement_id_present?(platform) }
  #   )
  module CookiePolicy
    CATEGORIES = %w[essential analytics marketing].freeze
    # Date of the Community Engine core wording; a segment's `updated_on` can move "Last updated" later.
    CORE_UPDATED_ON = Date.new(2026, 11, 14)
    KEY_PATTERN = /\A[a-z0-9_]+(\.[a-z0-9_]+)+\z/i

    Segment = Struct.new(:key, :category, :title, :description, :cookies, :privacy_url, :updated_on, :condition,
                         keyword_init: true)
    Cookie = Struct.new(:name, :purpose, :duration, :provider, :party, keyword_init: true) do
      def third_party? = party.to_s == 'third'
    end
    # A segment resolved for one platform and locale: strings translated, cookies evaluated.
    Resolved = Struct.new(:key, :category, :title, :description, :cookies, :privacy_url, :updated_on,
                          keyword_init: true)

    class << self
      include Resolution

      def segments
        @segments ||= {}
      end

      def register(key, category:, **attributes)
        category = category.to_s
        raise ArgumentError, "category must be one of #{CATEGORIES.join(', ')}" unless CATEGORIES.include?(category)
        raise ArgumentError, 'key is required' if key.blank?

        segments[key.to_sym] = build_segment(key, category, attributes)
      end

      # Segments visible on the platform, resolved in the current locale, in registration order.
      def build_segment(key, category, attributes)
        Segment.new(key: key.to_sym, category:, title: attributes[:title], description: attributes[:description],
                    cookies: attributes.fetch(:cookies, []), privacy_url: attributes[:privacy_url],
                    updated_on: attributes[:updated_on], condition: attributes[:if])
      end

      def resolved_segments(platform)
        segments.values.filter_map { |segment| resolve(segment, platform) }
      end

      def grouped(platform)
        resolved = resolved_segments(platform)
        CATEGORIES.index_with { |category| resolved.select { |segment| segment.category == category } }
                  .reject { |_category, list| list.empty? }
      end

      def segments_for_category(platform, category)
        resolved_segments(platform).select { |segment| segment.category == category.to_s }
      end

      # Non-essential categories that visible segments belong to.
      def consent_categories(platform)
        resolved_segments(platform).map(&:category).uniq - %w[essential]
      end

      # Stable strings describing which consent-needing segments are visible (feeds Consent.policy_version).
      def consent_fingerprint(platform)
        resolved_segments(platform).reject { |segment| segment.category == 'essential' }
                                   .map { |segment| "segment:#{segment.key}:#{segment.category}" }
      end

      # Short hash of everything the policy page shows, for the "policy version" label.
      def version(platform)
        payload = resolved_segments(platform).map do |s|
          [s.key, s.category, s.title, s.description, s.privacy_url, s.cookies.map(&:to_h)]
        end
        Digest::SHA256.hexdigest(payload.to_json)[0, 8]
      end

      def last_updated(platform)
        ([CORE_UPDATED_ON] + resolved_segments(platform).filter_map(&:updated_on)).max
      end

      def reset!
        @segments = {}
        register_core_segments
      end

      def register_core_segments
        register(:session, category: :essential, title: 'better_together.cookie_policy.core.session.title',
                           description: 'better_together.cookie_policy.core.session.description',
                           cookies: core_session_cookies, updated_on: CORE_UPDATED_ON)
        register(:consent, category: :essential, title: 'better_together.cookie_policy.core.consent.title',
                           description: 'better_together.cookie_policy.core.consent.description',
                           cookies: core_consent_cookies, updated_on: CORE_UPDATED_ON)
      end

      private

      def core_session_cookies
        [
          { name: '_better_together_session', purpose: 'better_together.cookie_policy.core.session.cookies.session',
            duration: 'better_together.cookie_policy.core.durations.session_inactivity', provider: nil, party: :first },
          { name: 'remember_user_token', purpose: 'better_together.cookie_policy.core.session.cookies.remember',
            duration: 'better_together.cookie_policy.core.durations.two_weeks', provider: nil, party: :first },
          { name: '_csrf_token', purpose: 'better_together.cookie_policy.core.session.cookies.csrf',
            duration: 'better_together.cookie_policy.core.durations.session', provider: nil, party: :first }
        ]
      end

      def core_consent_cookies
        [{ name: 'bt_consent', purpose: 'better_together.cookie_policy.core.consent.cookies.consent',
           duration: 'better_together.cookie_policy.core.durations.consent_days', provider: nil, party: :first }]
      end
    end

    reset!
  end

  class << self
    def register_cookie_policy_segment(key, **)
      CookiePolicy.register(key, **)
    end
  end
end
