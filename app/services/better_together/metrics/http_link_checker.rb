# frozen_string_literal: true

require 'net/http'
require 'uri'

module BetterTogether
  module Metrics
    # Service to perform HTTP checks for a given URI with simple retry logic.
    # Returns a struct with :success, :status_code, :error
    CheckResult = Struct.new(:success, :status_code, :error)

    # Performs a HEAD request with configurable timeouts and retries. The
    # service returns a CheckResult struct indicating success, the HTTP
    # status code (string) and any error encountered.
    class HttpLinkChecker
      DEFAULT_RETRIES = 2
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 5

      def initialize(uri, retries: DEFAULT_RETRIES,
                     open_timeout: DEFAULT_OPEN_TIMEOUT,
                     read_timeout: DEFAULT_READ_TIMEOUT)
        @uri = URI.parse(uri)
        @retries = retries
        @open_timeout = open_timeout
        @read_timeout = read_timeout
      end

      def call
        attempts = 0
        begin
          attempts += 1
          response = http_head(@uri)
          CheckResult.new(response.is_a?(Net::HTTPSuccess), response.code.to_s, nil)
        rescue StandardError => e
          retry if attempts <= @retries
          CheckResult.new(false, nil, e)
        end
      end

      private

      def http_head(uri)
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        ) do |http|
          request = Net::HTTP::Head.new(uri.request_uri)
          http.request(request)
        end
      end
    end
  end
end
