# frozen_string_literal: true

# Visitor consent for analytics and marketing code.
module BetterTogether
  # Visitor consent for analytics and marketing code. The decision lives in the `bt_consent`
  # cookie (JSON), written by the consent banner. Extension gems that load tracking code
  # register a provider so the banner appears only when something needs consent.
  module Consent
    COOKIE = 'bt_consent'
    CATEGORIES = %w[analytics marketing].freeze

    class << self
      def providers
        @providers ||= {}
      end

      def register_provider(key, callable = nil, &block)
        provider = callable || block
        raise ArgumentError, 'provider must respond to call' unless provider.respond_to?(:call)

        providers[key.to_sym] = provider
      end

      # True when any registered provider needs consent for the platform. A failing provider
      # counts as needing consent, so a bug never silently skips the banner.
      def provider_requires?(platform)
        providers.values.any? { |provider| provider.call(platform) }
      rescue StandardError
        true
      end

      # Parses the cookie value into { 'analytics' => bool, 'marketing' => bool }, or nil when
      # the visitor has not decided (or the cookie is malformed).
      def parse(raw)
        data = JSON.parse(raw.to_s)
        return unless data.is_a?(Hash) && data['v'] == 1

        CATEGORIES.index_with { |category| data[category] == true }
      rescue JSON::ParserError
        nil
      end

      def reset!
        @providers = {}
      end
    end
  end

  class << self
    def register_consent_provider(key, callable = nil, &)
      Consent.register_provider(key, callable, &)
    end
  end
end
