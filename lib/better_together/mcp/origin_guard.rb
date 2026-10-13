# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Replaces fast-mcp's Origin check, which only runs when a static allowed_origins list is non-empty
    # (an empty list disables it) and cannot follow the platform's domains.
    #
    # The hostname of the Origin header (falling back to the referer, then the request host, as fast-mcp
    # does) must be one of BetterTogether::Mcp::AllowedOrigins. A request to an unknown Host is therefore
    # refused too, which is the DNS rebinding case. Hostnames only: scheme and port are not compared.
    #
    # Prepended onto FastMcp::Transports::RackTransport (see config/initializers/fast_mcp.rb) and fragile
    # in the same way as SseConcurrencyGuard: re-verify if fast-mcp changes validate_origin or
    # extract_hostname.
    module OriginGuard
      def validate_origin(request, env) # rubocop:disable Naming/PredicateMethod
        origin = env['HTTP_ORIGIN']
        origin = env['HTTP_REFERER'] || request.host if origin.nil? || origin.empty?

        hostname = extract_hostname(origin)
        return true if hostname.nil?
        return true if BetterTogether::Mcp::AllowedOrigins.allowed?(hostname)

        @logger&.warn("Blocked request with origin: #{hostname}")
        false
      end
    end
  end
end
