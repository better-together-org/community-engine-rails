# frozen_string_literal: true

module BetterTogether
  # OmniAuth `setup:` hook: injects per-request client credentials for a catalog
  # provider, resolved from the platform serving the request.
  class OmniauthSetup
    def self.call(key, env)
      creds = IdentityProviderCredentials.resolve(key, domain: OmniauthFullHost.domain_for(env))
      apply(env['omniauth.strategy'].options, creds) if creds
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("[OAuth] credential resolution failed for #{key}: #{e.class}")
    end

    def self.apply(options, creds)
      options[:client_id] = creds.client_id
      options[:client_secret] = creds.client_secret
      options[:scope] = creds.scope if creds.scope.present?
      creds.options.each { |k, v| options[k.to_sym] = v }
    end
  end
end
