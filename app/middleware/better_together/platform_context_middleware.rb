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
      platform = domain&.platform || BetterTogether::Platform.find_by(host: true)

      BetterTogether::Current.platform_domain = domain
      BetterTogether::Current.platform        = platform

      @app.call(env)
    ensure
      BetterTogether::Current.reset
    end
  end
end
