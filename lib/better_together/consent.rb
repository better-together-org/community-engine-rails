# frozen_string_literal: true

require 'digest'
require 'json'

# Better Together engine namespace.
module BetterTogether
  # Consent for analytics and marketing code. The decision lives in the `bt_consent` cookie (JSON),
  # written by the consent banner or the settings form. For a signed-in person the decision is also
  # stored on their record and is the source of truth (see ConsentCookieSync). Extension gems that
  # load tracking code register a provider so consent controls appear only when something needs them.
  module Consent
    COOKIE = 'bt_consent'
    CATEGORIES = %w[analytics marketing].freeze
    COOKIE_DAYS = 180
    # Bump when the stored shape or the meaning of a category changes. Registered providers and
    # cookie policy segments also feed the policy version, so adding one re-asks everyone.
    BASE_POLICY_VERSION = 1

    class << self
      def providers
        @providers ||= {}
      end

      # A provider is a callable taking the platform. Return false/nil when no consent is needed,
      # true when it needs every category, or the categories it uses (for example :analytics or
      # %i[analytics marketing]) so the consent controls list only what is really in use.
      def register_provider(key, callable = nil, &block)
        provider = callable || block
        raise ArgumentError, 'provider must respond to call' unless provider.respond_to?(:call)

        providers[key.to_sym] = provider
      end

      # True when any registered provider needs consent for the platform. A failing provider
      # counts as needing consent, so a bug never silently skips the banner.
      def provider_requires?(platform)
        provider_categories(platform).any?
      end

      # Categories used by registered providers: a subset of CATEGORIES. A failing provider counts
      # as using every category.
      def provider_categories(platform)
        providers.values.flat_map { |provider| normalize_categories(provider.call(platform)) }.uniq
      rescue StandardError
        CATEGORIES.dup
      end

      # Categories some provider or visible cookie policy segment uses on this platform.
      def categories_in_use(platform)
        (provider_categories(platform) + CookiePolicy.consent_categories(platform)).uniq & CATEGORIES
      end

      # Short identifier of what the platform asks consent for. It changes when a provider or a
      # non-essential cookie policy segment appears, disappears or changes category, which is what
      # makes everyone decide again. Never includes the visitor's own data.
      def policy_version(platform)
        parts = ["base#{BASE_POLICY_VERSION}"]
        providers.each do |key, provider|
          parts << "provider:#{key}:#{provider_categories_for(provider, platform).sort.join(',')}"
        end
        parts.concat(CookiePolicy.consent_fingerprint(platform))
        Digest::SHA256.hexdigest(parts.sort.join('|'))[0, 10]
      end

      # Parses the cookie value into { 'analytics' => bool, 'marketing' => bool }, or nil when
      # the visitor has not decided (or the cookie is malformed).
      def parse(raw)
        data = parse_hash(raw)
        return unless data

        CATEGORIES.index_with { |category| data[category] == true }
      end

      # Policy version recorded in the cookie, or nil.
      def parse_policy_version(raw)
        parse_hash(raw)&.fetch('pv', nil)
      end

      # The cookie value for a decision made under a policy version.
      def serialize(decision, policy_version)
        values = CATEGORIES.index_with { |category| decision.to_h.stringify_keys[category] == true }
        JSON.generate({ 'v' => 1, **values, 'pv' => policy_version })
      end

      # Attributes shared by every server-side write of the cookie. The banner's JavaScript sets the
      # same path, SameSite and expiry, so the two writers never disagree.
      def cookie_options(secure: false)
        { path: '/', expires: COOKIE_DAYS.days.from_now, same_site: :lax, secure:, httponly: false }
      end

      def reset!
        @providers = {}
        CookiePolicy.reset!
      end

      private

      def parse_hash(raw)
        data = JSON.parse(raw.to_s)
        data.is_a?(Hash) && data['v'] == 1 ? data : nil
      rescue JSON::ParserError
        nil
      end

      def provider_categories_for(provider, platform)
        normalize_categories(provider.call(platform))
      rescue StandardError
        CATEGORIES.dup
      end

      def normalize_categories(result)
        return [] if result.blank? || result == false
        return CATEGORIES.dup if result == true

        Array(result).map(&:to_s) & CATEGORIES
      end
    end
  end

  class << self
    def register_consent_provider(key, callable = nil, &)
      Consent.register_provider(key, callable, &)
    end
  end
end
