# frozen_string_literal: true

module BetterTogether
  # Sends visitors who arrive on a platform's secondary domain to its primary domain, so each
  # platform has one canonical address for pages, search and sign-in.
  #
  # Runs after PlatformContextMiddleware. Only safe, browser-facing requests are redirected:
  # GET and HEAD, never API, MCP, OAuth, federation, well-known, asset, cable or health paths and never
  # a request carrying an Authorization header. The share
  # domain and the primary domain are never redirected. A platform with no active primary
  # domain, or with `redirect_secondary_domains` turned off, serves every domain as before.
  class SecondaryDomainRedirectMiddleware
    SKIPPED_PREFIXES = %w[
      /assets/ /packs/ /rails/ /cable /up /health /sidekiq /api/ /mcp /.well-known/ /oauth /users/auth
    ].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      target = canonical_url_for(request) if candidate?(request)
      return @app.call(env) unless target

      [301, { 'Location' => target, 'Content-Type' => 'text/plain; charset=utf-8', 'Cache-Control' => 'public, max-age=300' },
       ['Moved Permanently']]
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("[SecondaryDomainRedirectMiddleware] #{e.class}: #{e.message}")
      @app.call(env)
    end

    private

    def candidate?(request)
      return false unless request.get? || request.head?
      # Machine clients (federation peers, API tokens) must reach the address they were given.
      return false if request.authorization.present? || request.path.include?('/federation/')

      SKIPPED_PREFIXES.none? { |prefix| request.path.start_with?(prefix) }
    end

    def canonical_url_for(request)
      primary = canonical_domain_for(::Current.platform, ::Current.platform_domain)
      "#{primary.url}#{port_suffix(request)}#{request.fullpath}" if primary
    end

    # The primary domain to send this request to, or nil when the request should be served as is.
    def canonical_domain_for(platform, domain)
      return unless domain && platform&.redirect_secondary_domains?
      return if domain.primary? || domain.share_domain?

      platform.primary_platform_domain.presence
    end

    # Keeps a non-standard port (development, tests) on the canonical address.
    def port_suffix(request)
      port = request.port
      [80, 443].include?(port) ? '' : ":#{port}"
    end
  end
end
