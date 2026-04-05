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
      platform = domain&.platform || cached_host_platform

      ::Current.platform_domain = domain
      ::Current.platform        = platform

      @app.call(env)
    ensure
      ::Current.reset
      ActiveStorage::Current.reset if defined?(ActiveStorage::Current)
    end

    private

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
