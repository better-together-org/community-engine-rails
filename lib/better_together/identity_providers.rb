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
      :requires_issuer, :configure,
      keyword_init: true
    ) do
      def env_vars
        [env_id, env_secret].compact
      end

      # Applies catalog-specific OmniAuth options (e.g. OIDC client_options) after the generic ones.
      def configure_options(options, creds, env)
        configure&.call(options, creds, env)
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

# Facebook never asserts that an email address is verified, so no verified_email rule is given:
# a Facebook sign-in is never linked to an existing account by email, and a new account must
# confirm its address through the normal confirmation email.
BetterTogether.register_identity_provider(
  :facebook,
  kind: 'Facebook',
  platform_identifier: 'facebook',
  platform_url: 'https://www.facebook.com',
  env_id: 'FACEBOOK_CLIENT_ID',
  env_secret: 'FACEBOOK_CLIENT_SECRET',
  scope: 'email,public_profile',
  icon_class: 'fa-brands fa-facebook',
  button_class: 'btn btn-primary'
)

# Generic OpenID Connect relying party: the issuer is configured per platform (see
# PlatformIdentityProvider#issuer), so one catalog entry serves any compliant provider.
# Email counts as verified only when the provider asserts email_verified.
BetterTogether.register_identity_provider(
  :openid_connect,
  kind: 'OpenID Connect',
  platform_identifier: 'openid_connect',
  platform_url: 'https://openid.net/connect/',
  env_id: nil,
  env_secret: nil,
  scope: 'openid email profile',
  icon_class: 'fa-solid fa-id-badge',
  button_class: 'btn btn-outline-primary',
  requires_issuer: true,
  configure: lambda { |options, creds, env|
    issuer = creds.options['issuer'] || creds.options[:issuer]
    options[:issuer] = issuer
    options[:discovery] = true
    options[:response_type] = :code
    options[:pkce] = true
    options[:client_options] = {
      identifier: creds.client_id,
      secret: creds.client_secret,
      redirect_uri: "#{BetterTogether::OmniauthFullHost.call(env)}/users/auth/openid_connect/callback"
    }
  },
  verified_email: lambda { |auth|
    info = auth&.info
    claim = info&.email_verified
    claim = auth.extra&.raw_info&.email_verified if claim.nil? && auth
    info&.email.present? && [true, 'true'].include?(claim)
  }
)
