# frozen_string_literal: true

module BetterTogether
  # Rack middleware inserted immediately before ActionDispatch::RemoteIp.
  #
  # RemoteIp raises ActionDispatch::RemoteIp::IpSpoofAttackError when it sees a
  # X-Forwarded-For value it considers inconsistent with HTTP_CLIENT_IP (e.g. a
  # loopback address alongside a real IP). In practice this fires almost
  # exclusively for automated WordPress/scanner bot traffic, not real spoofing
  # attempts against this app -- and because RemoteIp runs before Rack::Attack
  # in the default middleware stack, none of the existing scanner blocklists in
  # config/initializers/rack_attack.rb ever get a chance to intercept it. Every
  # occurrence was reaching Sentry as an unhandled 500, burning event quota.
  #
  # This middleware does not change what counts as spoofed -- it only catches
  # the raise at the Rack layer and returns the same style of response
  # Rack::Attack's blocklisted_responder already uses for scanner traffic,
  # instead of letting it propagate into an ActionDispatch 500.
  class SpoofedForwardedForGuardMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError => e
      log_spoofed_forwarded_for(env, e)
      blocked_response
    end

    private

    def log_spoofed_forwarded_for(env, error)
      Rails.logger.warn(
        "[spoofed_forwarded_for_guard] #{error.message} " \
        "path=#{env['PATH_INFO']} ua=#{env['HTTP_USER_AGENT']}"
      )
    end

    def blocked_response
      [503, {}, ['Blocked']]
    end
  end
end
