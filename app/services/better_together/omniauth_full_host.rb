# frozen_string_literal: true

module BetterTogether
  # Resolves the scheme and host OmniAuth uses to build OAuth callback URLs
  # (GHSA-m27g-v28p-f9fx). The request Host / X-Forwarded-Host header is only
  # trusted when it names an active PlatformDomain; any other value falls back
  # to the host platform's canonical URL, so a forged header cannot steer the
  # provider's redirect_uri to another site.
  class OmniauthFullHost
    def self.call(env)
      new(env).call
    end

    def initialize(env)
      @env = env
    end

    def call
      known_domain_url || host_platform_url || configured_url
    end

    private

    def known_domain_url
      hostname = Rack::Request.new(@env).host
      PlatformDomain.resolve(hostname)&.url
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def host_platform_url
      Platform.find_by(host: true)&.resolved_host_url.presence
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def configured_url
      "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"
    end
  end
end
