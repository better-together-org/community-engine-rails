# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module BetterTogether
  # Pulls one linked-private seed batch for a specific recipient from a federated peer platform.
  class FederatedLinkedSeedPullService
    DEFAULT_LIMIT = 50
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 15

    Result = Struct.new(
      :connection,
      :recipient_identifier,
      :seeds,
      :next_cursor,
      keyword_init: true
    )

    def self.call(connection:, recipient_identifier:, cursor: nil, limit: DEFAULT_LIMIT)
      new(connection:, recipient_identifier:, cursor:, limit:).call
    end

    def initialize(connection:, recipient_identifier:, cursor: nil, limit: DEFAULT_LIMIT)
      @connection = connection
      @recipient_identifier = recipient_identifier.to_s
      @cursor = cursor
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      raise ArgumentError, 'connection is required' unless connection
      raise ArgumentError, 'recipient_identifier is required' if recipient_identifier.blank?

      response = http_get(feed_uri)
      raise "linked seed feed request failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)

      Result.new(
        connection:,
        recipient_identifier:,
        seeds: payload['seeds'] || [],
        next_cursor: payload['next_cursor']
      )
    end

    private

    attr_reader :connection, :recipient_identifier, :cursor, :limit

    def feed_uri
      base_uri = URI.parse(connection.source_platform.resolved_host_url)
      base_uri.path = ::BetterTogether::Engine.routes.url_helpers.federation_linked_seeds_path(locale: I18n.default_locale)
      params = { limit:, recipient_identifier: }
      params[:cursor] = cursor if cursor.present?
      base_uri.query = params.to_query
      base_uri
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
      response = http_post_form(token_uri, {
                                  grant_type: 'client_credentials',
                                  client_id: connection.oauth_client_id,
                                  client_secret: connection.oauth_client_secret,
                                  scope: 'linked_content.read'
                                })
      raise 'linked seed token request failed' unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch('access_token')
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
