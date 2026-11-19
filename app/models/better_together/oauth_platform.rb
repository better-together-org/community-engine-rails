# frozen_string_literal: true

module BetterTogether
  # An OAuth or OIDC identity provider placeholder (GitHub, Google, Facebook, LinkedIn, issuer-based OIDC).
  class OauthPlatform < Platform
    include PlatformSubtype

    STATIC_IDENTIFIERS = %w[github google facebook linkedin].freeze
    OIDC_IDENTIFIER_PATTERN = /\Aoidc-[0-9a-f]{16}\z/

    class << self
      # True for the identifiers the OAuth code creates: the static providers, registered catalog entries and
      # issuer-derived OIDC identifiers. Federated peers never match.
      def provider_identifier?(identifier)
        identifier = identifier.to_s
        STATIC_IDENTIFIERS.include?(identifier) ||
          OIDC_IDENTIFIER_PATTERN.match?(identifier) ||
          BetterTogether::IdentityProviders.registry.values.any? { |p| p.platform_identifier.to_s == identifier }
      end

      # Finds the provider platform whatever its type, else creates it as an OauthPlatform.
      def find_or_create_provider!(identifier, &)
        Platform.remote.find_by(identifier:) || create!(identifier:, locality: 'remote', host: false, &)
      end
    end
  end
end
