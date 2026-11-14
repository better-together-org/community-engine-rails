# frozen_string_literal: true

module BetterTogether
  # Rack middleware that resolves Current.platform for every request —
  # web, API (JSONAPI), and MCP — before any controller action runs.
  #
  # This ensures Current.platform is always set from the request's Host
  # header, even for controllers that don't inherit from
  # BetterTogether::ApplicationController (e.g. Api::ApplicationController
  # which inherits from JSONAPI::ResourceController, and FastMcp tools).
  #
  # The middleware mirrors set_current_platform_context in ApplicationController
  # but operates at the Rack layer so all stacks benefit.
  #
  # BetterTogether::ApplicationController still calls with_current_platform_context
  # around each action to cover the url_options / ActiveStorage::Current setup
  # that requires the full Rails request object. There is no double-write risk:
  # setting Current.platform twice with the same value is idempotent.
  class PlatformContextMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      hostname = ActionDispatch::Request.new(env).host
      domain   = BetterTogether::PlatformDomain.resolve(hostname)
      platform = domain&.platform
      platform ||= fallback_platform(env, hostname)
      return not_found_response if platform == :refuse

      ::Current.platform_domain = domain
      ::Current.platform        = platform

      @app.call(env)
    ensure
      ::Current.reset
      ActiveStorage::Current.reset if defined?(ActiveStorage::Current)
    end

    HEALTH_PATHS = %w[/up /health /healthz /health_check].freeze

    private

    # Unknown hostnames fall back to the host platform only when that is
    # unambiguous: fail-closed is off, there is a single platform, the host
    # matches the host platform's own URL, or the path is a health check.
    # Returns :refuse when the request must be rejected.
    def fallback_platform(env, hostname)
      host_platform = cached_host_platform
      return host_platform unless host_platform && BetterTogether.fail_closed_unknown_hosts
      return host_platform if HEALTH_PATHS.include?(env['PATH_INFO'].to_s)
      return host_platform if own_host?(host_platform, hostname)
      return host_platform if single_platform?

      :refuse
    end

    def own_host?(platform, hostname)
      URI.parse(platform.host_url.to_s).host.to_s.casecmp?(hostname.to_s)
    rescue URI::InvalidURIError
      false
    end

    def single_platform?
      Rails.cache.fetch('better_together/single_platform', expires_in: 1.minute) do
        BetterTogether::Platform.where(external: false).limit(2).count < 2
      end
    end

    def not_found_response
      [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
    end

    def cached_host_platform
      # Cache only the UUID to avoid serializing an AR object into the cache store.
      # Caching a full ActiveRecord object as YAML triggers Psych::DisallowedClass on
      # read when Psych safe-load mode is active (Psych 4 / Ruby 3.1+), causing every
      # request to 500 after the first cache write. Storing only the UUID is safe and
      # still eliminates the DB query on the hot path.
      id = Rails.cache.fetch('better_together/host_platform_id', expires_in: 5.minutes) do
        BetterTogether::Platform.where(host: true).pick(:id)
      end
      id ? BetterTogether::Platform.find_by(id: id) : nil
    end
  end
end
