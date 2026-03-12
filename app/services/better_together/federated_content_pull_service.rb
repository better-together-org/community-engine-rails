# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module BetterTogether
  # Pulls one content-feed batch from a federated peer platform.
  class FederatedContentPullService
    DEFAULT_LIMIT = 50
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 15

    Result = Struct.new(
      :connection,
      :seeds,
      :next_cursor,
      keyword_init: true
    ) do
      def items
        seeds
      end
    end

    def self.call(connection:, cursor: nil, limit: DEFAULT_LIMIT)
      new(connection:, cursor:, limit:).call
    end

    def initialize(connection:, cursor: nil, limit: DEFAULT_LIMIT)
      @connection = connection
      @cursor = cursor
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      raise ArgumentError, 'connection is required' unless connection

      response = http_get(feed_uri)
      raise "federation feed request failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)

      Result.new(
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
        request['Authorization'] = "Bearer #{connection.federation_access_token}"
        request['Accept'] = 'application/json'
        http.request(request)
      end
    end
  end
end
