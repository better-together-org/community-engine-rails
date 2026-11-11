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

    # The PlatformDomain whose URL call returns: the requested host when it is a known active
    # domain, otherwise the host platform's own domain. OAuth authorization is checked against this.
    def self.domain_for(env)
      PlatformDomain.resolve(Rack::Request.new(env).host) || host_platform_domain
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def self.host_platform_domain
      platform = Platform.find_by(host: true)
      platform&.share_platform_domain || platform&.primary_platform_domain
    end
    private_class_method :host_platform_domain

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
