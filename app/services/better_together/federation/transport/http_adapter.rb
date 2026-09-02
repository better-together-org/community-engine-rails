# frozen_string_literal: true

require 'json'
require 'net/http'
require 'ssrf_filter'
require 'socket'
require 'time'
require 'uri'
require 'cgi'

module BetterTogether
  module Federation
    module Transport
      # Fetches a federation feed over the existing HTTP+OAuth transport.
      class HttpAdapter # rubocop:disable Metrics/ClassLength
        DEFAULT_OPEN_TIMEOUT = 5
        DEFAULT_READ_TIMEOUT = 15
        DEFAULT_CONNECT_TIMEOUT = 2

        # Raised when an outbound federation request targets a private/loopback address.
        class SSRFError < StandardError; end

        # Raised when the remote rate-limits us (HTTP 429/503). Carries the
        # server's requested cool-off (`Retry-After`, in seconds) when present so
        # the caller can schedule the next attempt politely instead of retrying
        # immediately.
        class RateLimitedError < StandardError
          attr_reader :retry_after

          def initialize(message, retry_after: nil)
            super(message)
            @retry_after = retry_after
          end
        end

        RATE_LIMIT_CODES = %w[429 503].freeze

        def self.call(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          new(connection:, cursor:, limit:).call
        end

        def self.accessible?(connection:)
          new(connection:).accessible?
        end

        def initialize(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          @connection = connection
          @cursor = cursor
          @limit = limit.to_i.positive? ? limit.to_i : BetterTogether::FederatedContentPullService::DEFAULT_LIMIT
        end

        def accessible?
          [feed_uri, token_uri].all? { |uri| host_reachable?(uri) }
        rescue URI::InvalidURIError, SocketError, SystemCallError, ArgumentError
          false
        end

        def call
          raise ArgumentError, 'connection is required' unless connection

          response = fetch_feed_response
          raise_feed_status_errors(response)
          build_result(JSON.parse(response.body))
        end

        private

        attr_reader :connection, :cursor, :limit

        def raise_feed_status_errors(response)
          raise rate_limited_error(response) if RATE_LIMIT_CODES.include?(response.code)
          raise federation_error(response) unless response.is_a?(Net::HTTPSuccess)
        end

        def build_result(payload)
          ::BetterTogether::FederatedContentPullService::Result.new(
            connection:,
            seeds: payload['seeds'] || payload.fetch('items', []),
            next_cursor: payload['next_cursor']
          )
        end

        # A cached token can be rejected by the remote (revoked/rotated) before its local
        # TTL expires. On a 401 we invalidate the cache and retry once with a freshly
        # issued token before giving up.
        def fetch_feed_response
          response = http_get(feed_uri)
          return response unless response.code == '401'

          Rails.cache.delete(token_cache_key)
          http_get(feed_uri)
        end

        def federation_error(response)
          "federation feed request failed with #{response.code} for connection #{connection.id} " \
            "(#{connection_host})"
        end

        def rate_limited_error(response, context: 'feed')
          message = "federation #{context} request rate-limited (HTTP #{response.code}) for " \
                    "connection #{connection.id} (#{connection_host})"
          RateLimitedError.new(message, retry_after: parse_retry_after(response))
        end

        # `Retry-After` is either a delta in seconds or an HTTP-date. Return an
        # integer number of seconds, or nil if absent/unparseable.
        def parse_retry_after(response)
          raw = response['retry-after'].to_s.strip
          return if raw.empty?
          return raw.to_i if raw.match?(/\A\d+\z/)

          seconds = (Time.httpdate(raw) - Time.current).round
          seconds.positive? ? seconds : nil
        rescue ArgumentError
          nil
        end

        # The connection's two platform sides don't encode "local vs remote" by
        # position (source/target reflect who initiated the link, not who's local) —
        # resolve the actual federated peer via its external flag instead of assuming
        # source_platform is always the remote. See PlatformFederationStatus.
        def remote_platform
          @remote_platform ||= [connection.source_platform, connection.target_platform].find(&:external_peer?)
        end

        def connection_host
          remote_platform&.resolved_host_url
        end

        def feed_uri
          base_uri = URI.parse(remote_platform.resolved_host_url)
          base_uri.path = feed_path
          params = { limit: }
          params[:cursor] = cursor if cursor.present?
          base_uri.query = params.to_query
          base_uri
        end

        def feed_path
          ::BetterTogether::Engine.routes.url_helpers.federation_content_feed_path(locale: I18n.default_locale)
        end

        def http_get(uri)
          SsrfFilter.get(
            uri.to_s,
            headers: {
              'Authorization' => "Bearer #{access_token_for_request}",
              'Accept' => 'application/json'
            },
            http_options: {
              open_timeout: DEFAULT_OPEN_TIMEOUT,
              read_timeout: DEFAULT_READ_TIMEOUT
            }
          )
        rescue SsrfFilter::PrivateIPAddress, SsrfFilter::TooManyRedirects, SsrfFilter::UnresolvedHostname => e
          raise SSRFError, e.message
        end

        def access_token_for_request
          oauth_access_token || raise(
            "content feed token request failed for connection #{connection.id} (#{connection_host})"
          )
        end

        def token_cache_key
          "bt:fed_token:#{connection.oauth_client_id}"
        end

        def oauth_access_token
          return if connection.oauth_client_id.blank? || connection.oauth_client_secret.blank?

          cached = Rails.cache.read(token_cache_key)
          return cached if cached.present?

          fetch_and_cache_oauth_token(token_cache_key)
        end

        def fetch_and_cache_oauth_token(cache_key)
          response = http_post_form(token_uri, oauth_token_request_params)
          raise rate_limited_error(response, context: 'token') if RATE_LIMIT_CODES.include?(response.code)

          unless response.is_a?(Net::HTTPSuccess)
            log_token_response_failure(response)
            return
          end

          cache_oauth_token(cache_key, JSON.parse(response.body))
        rescue JSON::ParserError, KeyError => e
          log_token_parse_failure(e)
          nil
        end

        def cache_oauth_token(cache_key, body)
          token = body.fetch('access_token')
          ttl   = body.fetch('expires_in', 840).to_i
          Rails.cache.write(cache_key, token, expires_in: ttl.seconds)
          token
        end

        def log_token_response_failure(response)
          Rails.logger.warn(
            "[BetterTogether::Federation] token request for connection #{connection.id} " \
            "(#{connection_host}) failed: HTTP #{response.code} #{response.body.to_s.truncate(200)}"
          )
        end

        def log_token_parse_failure(error)
          Rails.logger.warn(
            "[BetterTogether::Federation] token response for connection #{connection.id} " \
            "(#{connection_host}) could not be parsed: #{error.class}: #{error.message}"
          )
        end

        def oauth_token_request_params
          {
            grant_type: 'client_credentials',
            client_id: connection.oauth_client_id,
            client_secret: connection.oauth_client_secret,
            scope: 'content.feed.read'
          }
        end

        def token_uri
          # Not remote_platform.effective_oauth_issuer_url: that helper only falls back to
          # resolved_host_url for community_engine? peers, and can return nil (URI.parse
          # would raise) for a non-CE federation partner with no oauth_issuer_url set.
          base_uri = URI.parse(remote_platform.oauth_issuer_url.presence || remote_platform.resolved_host_url)
          base_uri.path = ::BetterTogether::Engine.routes.url_helpers.federation_oauth_token_path(locale: I18n.default_locale)
          base_uri.query = nil
          base_uri
        end

        def http_post_form(uri, params)
          SsrfFilter.post(
            uri.to_s,
            headers: {
              'Accept' => 'application/json',
              'Content-Type' => 'application/x-www-form-urlencoded'
            },
            body: URI.encode_www_form(params),
            http_options: {
              open_timeout: DEFAULT_OPEN_TIMEOUT,
              read_timeout: DEFAULT_READ_TIMEOUT
            }
          )
        rescue SsrfFilter::PrivateIPAddress, SsrfFilter::TooManyRedirects, SsrfFilter::UnresolvedHostname => e
          raise SSRFError, e.message
        end

        def host_reachable?(uri)
          Socket.tcp(uri.host, uri.port, connect_timeout: DEFAULT_CONNECT_TIMEOUT) do |socket|
            socket.close unless socket.closed?
          end

          true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError, Timeout::Error, IO::TimeoutError
          false
        end
      end
    end
  end
end
