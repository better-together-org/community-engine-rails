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
      context = ::BetterTogether::PlatformRuntimeContextResolver.for_host(hostname)

      return external_platform_response if external_platform_route?(context)

      ::Current.platform_domain = context.platform_domain
      ::Current.platform = context.platform
      ::Current.tenant_schema = context.tenant_schema

      @app.call(env)
    ensure
      ::Current.reset
      ActiveStorage::Current.reset if defined?(ActiveStorage::Current)
    end

    private

    def external_platform_route?(context)
      context.domain_matched? && context.platform&.external?
    end

    def external_platform_response
      [404, { 'Content-Type' => 'text/plain; charset=utf-8' }, ['Not Found']]
    end
  end
end
