# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'cgi'

module BetterTogether
  module Federation
    module Transport
      # Fetches a federation feed over the existing HTTP+OAuth transport.
      class HttpAdapter # rubocop:disable Metrics/ClassLength
        DEFAULT_OPEN_TIMEOUT = 5
        DEFAULT_READ_TIMEOUT = 15

        def self.call(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          new(connection:, cursor:, limit:).call
        end

        def initialize(connection:, cursor: nil, limit: BetterTogether::FederatedContentPullService::DEFAULT_LIMIT)
          @connection = connection
          @cursor = cursor
          @limit = limit.to_i.positive? ? limit.to_i : BetterTogether::FederatedContentPullService::DEFAULT_LIMIT
        end

        def call
          raise ArgumentError, 'connection is required' unless connection

          response = http_get(feed_uri)
          raise "federation feed request failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          payload = JSON.parse(response.body)

          ::BetterTogether::FederatedContentPullService::Result.new(
            connection:,
            seeds: payload['seeds'] || payload.fetch('items', []),
            next_cursor: payload['next_cursor']
          )
        end

        private

        attr_reader :connection, :cursor, :limit

        def feed_uri
          base_uri = URI.parse(connection.source_platform.resolved_host_url)
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
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == 'https',
            open_timeout: DEFAULT_OPEN_TIMEOUT,
            read_timeout: DEFAULT_READ_TIMEOUT
          ) do |http|
            request = Net::HTTP::Get.new(uri.request_uri)
            request['Authorization'] = "Bearer #{access_token_for_request}"
            request['Accept'] = 'application/json'
            http.request(request)
          end
        end

        def access_token_for_request
          oauth_access_token || raise('content feed token request failed')
        end

        def oauth_access_token
          return if connection.oauth_client_id.blank? || connection.oauth_client_secret.blank?

          cache_key = "bt:fed_token:#{connection.oauth_client_id}"
          cached = Rails.cache.read(cache_key)
          return cached if cached.present?

          fetch_and_cache_oauth_token(cache_key)
        end

        def fetch_and_cache_oauth_token(cache_key)
          response = http_post_form(token_uri, oauth_token_request_params)
          return unless response.is_a?(Net::HTTPSuccess)

          body  = JSON.parse(response.body)
          token = body.fetch('access_token')
          ttl   = body.fetch('expires_in', 840).to_i
          Rails.cache.write(cache_key, token, expires_in: ttl.seconds)
          token
        rescue JSON::ParserError, KeyError
          nil
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
          base_uri = URI.parse(connection.source_platform.oauth_issuer_url.presence || connection.source_platform.resolved_host_url)
          base_uri.path = ::BetterTogether::Engine.routes.url_helpers.federation_oauth_token_path(locale: I18n.default_locale)
          base_uri.query = nil
          base_uri
        end

        def http_post_form(uri, params)
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == 'https',
            open_timeout: DEFAULT_OPEN_TIMEOUT,
            read_timeout: DEFAULT_READ_TIMEOUT
          ) do |http|
            request = Net::HTTP::Post.new(uri.request_uri)
            request['Accept'] = 'application/json'
            request['Content-Type'] = 'application/x-www-form-urlencoded'
            request.body = URI.encode_www_form(params)
            http.request(request)
          end
        end
      end
    end
  end
end
