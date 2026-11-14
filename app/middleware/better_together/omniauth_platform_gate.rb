# frozen_string_literal: true

module BetterTogether
  # Refuses OAuth request and callback phases on any domain the provider is not configured for.
  # The callback URL is derived from the requested host, so allowing the domain is what makes a
  # platform's callback URL valid; nothing falls back to another platform's configuration.
  class OmniauthPlatformGate
    PATH = %r{\A/users/auth/(?<key>[a-z0-9_]+)(?<callback>/callback)?/?\z}
    # The configuration chosen at the request phase (issuer-based providers can have several per domain).
    SESSION_KEY = 'bts.identity_provider_id'
    ENV_KEY = 'bts.identity_provider_id'
    UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    def initialize(app)
      @app = app
    end

    def call(env)
      match = PATH.match(env['PATH_INFO'].to_s)
      key = match&.[](:key)
      return @app.call(env) unless key && IdentityProviders.find(key)

      env[ENV_KEY] = selected_provider_id(env, callback: match[:callback].present?)
      return @app.call(env) if configured_for_request?(key, env)

      refuse(key, env)
    end

    private

    def configured_for_request?(key, env)
      IdentityProviderCredentials.configured?(key, domain: OmniauthFullHost.domain_for(env),
                                                   provider_id: env[ENV_KEY])
    end

    # Request phase: the id posted by the button, remembered in the session. Callback: the remembered id,
    # so the callback is handled by the same configuration the user started with.
    def selected_provider_id(env, callback:)
      session = env['rack.session']
      return valid_id(session&.[](SESSION_KEY)) if callback

      id = valid_id(Rack::Request.new(env).params['provider_id'])
      id ? session&.[]=(SESSION_KEY, id) : session&.delete(SESSION_KEY)
      id
    end

    def valid_id(value)
      value.to_s.match?(UUID) ? value.to_s : nil
    end

    def refuse(key, env)
      Rails.logger.warn("[OAuth] #{key} is not configured for host #{Rack::Request.new(env).host}")
      env['omniauth.error.type'] = :provider_not_configured_for_platform
      OmniAuth.config.on_failure.call(env)
    end
  end
end
