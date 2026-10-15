# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Caps total concurrent MCP SSE connections held open at once.
    #
    # fast-mcp's RackTransport (see gem source, lib/mcp/transports/rack_transport.rb)
    # already detects and cleans up dead connections promptly (Errno::EPIPE/IOError
    # in its keep-alive loop breaks and runs cleanup within one ~1s ping interval --
    # there is no "endless broken pipe" bug to fix there), and Rack::Attack's
    # `mcp/sse/ip` throttle (config/initializers/rack_attack.rb) bounds how fast any
    # one IP can open *new* connections. Neither bounds how many connections can be
    # *simultaneously held open* -- each SSE connection holds a web-server thread for
    # its lifetime (register_sse_client has no size check), so enough legitimately-slow
    # or slow-to-notice-disconnected clients can still exhaust the thread pool.
    #
    # This is a hard global backstop: prepended onto FastMcp::Transports::RackTransport
    # (see config/initializers/fast_mcp.rb), checked before a new SSE connection is
    # accepted. Deliberately global-only, not per-IP: fast-mcp does not expose the
    # requesting IP at the point a client_id is assigned (extract_client_id runs after
    # handle_sse_request), so a correct per-IP concurrency count would require
    # reaching further into gem internals than is safe via prepend. The per-IP
    # `mcp/sse/ip` rate throttle already substantially bounds per-IP accumulation.
    #
    # Fragile by nature (prepends onto a third-party gem's private method names) --
    # if `handle_sse_request`'s signature or behaviour changes on a fast-mcp upgrade,
    # this must be re-verified.
    module SseConcurrencyGuard
      MAX_GLOBAL_SSE_CONNECTIONS = ENV.fetch('MCP_SSE_MAX_GLOBAL_CONNECTIONS', 40).to_i

      def handle_sse_request(request, env)
        return super unless request.get?
        return over_capacity_response if sse_client_count >= MAX_GLOBAL_SSE_CONNECTIONS

        super
      end

      private

      def sse_client_count
        return 0 unless defined?(@sse_clients) && @sse_clients

        @sse_clients.size
      end

      def over_capacity_response
        if defined?(Rails)
          Rails.logger.warn(
            '[BetterTogether::Mcp] SSE connection rejected: at MAX_GLOBAL_SSE_CONNECTIONS ' \
            "(#{MAX_GLOBAL_SSE_CONNECTIONS})"
          )
        end

        [503, { 'Retry-After' => '10' }, ['']]
      end
    end
  end
end
