# frozen_string_literal: true

# Engine namespace.
module BetterTogether
  # Catalog of OmniAuth sign-in strategies the engine knows about. Devise needs
  # the strategy names at boot, so names live here; credentials, enabled state
  # and options are resolved per request (see IdentityProviderCredentials).
  module IdentityProviders
    # One catalog entry. `verified_email` receives the OmniAuth auth hash.
    Provider = Struct.new(
      :key, :kind, :platform_identifier, :platform_url, :env_id, :env_secret,
      :scope, :icon_class, :button_class, :verified_email,
      keyword_init: true
    ) do
      def env_vars
        [env_id, env_secret].compact
      end

      def verified_email?(auth)
        verified_email ? verified_email.call(auth) : false
      end
    end

    class << self
      def registry
        @registry ||= {}
      end

      def register(key, **attrs)
        registry[key.to_sym] = Provider.new(key: key.to_sym, **attrs)
      end

      def fetch(key)
        registry.fetch(key.to_sym)
      end

      def find(key)
        registry[key.to_s.to_sym]
      end

      def keys
        registry.keys
      end

      def each(&)
        registry.values.each(&)
      end

      def clear!
        @registry = {}
      end
    end
  end

  def self.register_identity_provider(key, **)
    IdentityProviders.register(key, **)
  end
end

# Strategies shipped with the engine. Host apps may register more.
BetterTogether.register_identity_provider(
  :github,
  kind: 'Github',
  platform_identifier: 'github',
  platform_url: 'https://github.com',
  env_id: 'GITHUB_CLIENT_ID',
  env_secret: 'GITHUB_CLIENT_SECRET',
  scope: 'user:email',
  icon_class: 'fa-brands fa-github',
  button_class: 'btn btn-dark',
  # GitHub emails come from the user:email API; omniauth-github returns the primary verified one.
  verified_email: lambda { |auth|
    email = auth&.info&.email.to_s.downcase
    entries = Array(auth&.extra&.all_emails)
    email.present? && entries.any? do |e|
      e['email'].to_s.downcase == email && e['verified'] == true
    end
  }
)

BetterTogether.register_identity_provider(
  :google_oauth2,
  kind: 'Google',
  platform_identifier: 'google',
  platform_url: 'https://accounts.google.com',
  env_id: 'GOOGLE_CLIENT_ID',
  env_secret: 'GOOGLE_CLIENT_SECRET',
  scope: 'email,profile',
  icon_class: 'fa-brands fa-google',
  button_class: 'btn btn-outline-danger',
  # Google asserts email_verified in the ID token claims; absent or false means unverified.
  verified_email: ->(auth) { auth&.info&.email.present? && [true, 'true'].include?(auth.info.email_verified) }
)
