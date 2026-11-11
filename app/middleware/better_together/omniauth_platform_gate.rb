# frozen_string_literal: true

module BetterTogether
  # Refuses OAuth request and callback phases on any domain the provider is not configured for.
  # The callback URL is derived from the requested host, so allowing the domain is what makes a
  # platform's callback URL valid; nothing falls back to another platform's configuration.
  class OmniauthPlatformGate
    PATH = %r{\A/users/auth/(?<key>[a-z0-9_]+)(?:/callback)?/?\z}

    def initialize(app)
      @app = app
    end

    def call(env)
      key = PATH.match(env['PATH_INFO'].to_s)&.[](:key)
      return @app.call(env) unless key && IdentityProviders.find(key)
      return @app.call(env) if configured_for_request?(key, env)

      refuse(key, env)
    end

    private

    def configured_for_request?(key, env)
      IdentityProviderCredentials.configured?(key, domain: OmniauthFullHost.domain_for(env))
    end

    def refuse(key, env)
      Rails.logger.warn("[OAuth] #{key} is not configured for host #{Rack::Request.new(env).host}")
      env['omniauth.error.type'] = :provider_not_configured_for_platform
      OmniAuth.config.on_failure.call(env)
    end
  end
end
