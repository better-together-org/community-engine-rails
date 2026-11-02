# frozen_string_literal: true

require 'ssrf_filter'

module BetterTogether
  module Weather
    # Small bounded-time HTTP client shared by weather adapters. Identifies itself
    # with a descriptive User-Agent and refuses private/loopback targets.
    class Http
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 20
      RATE_LIMIT_CODES = %w[429 503].freeze

      class Error < StandardError; end
      class NotFound < Error; end

      # Raised on HTTP 429/503; carries the server's Retry-After seconds when sent.
      class RateLimited < Error
        attr_reader :retry_after

        def initialize(message, retry_after: nil)
          super(message)
          @retry_after = retry_after
        end
      end

      def self.user_agent
        contact = ENV.fetch('WEATHER_CONTACT', nil).presence || 'https://bettertogethersolutions.com'
        "BetterTogether-CommunityEngine-Weather/1.0 (+#{contact})"
      end

      def get(url, params: {})
        response = SsrfFilter.get(
          url,
          params: params,
          headers: { 'User-Agent' => self.class.user_agent, 'Accept' => '*/*' },
          http_options: { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
        )
        check!(response, url)
        response.body
      rescue SsrfFilter::Error, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
        raise Error, "#{e.class}: #{e.message}"
      end

      private

      def check!(response, url)
        code = response.code.to_s
        return if code.start_with?('2')
        raise NotFound, "HTTP 404 for #{url}" if code == '404'

        if RATE_LIMIT_CODES.include?(code)
          raise RateLimited.new("HTTP #{code} for #{url}", retry_after: response['Retry-After']&.to_i)
        end

        raise Error, "HTTP #{code} for #{url}"
      end
    end
  end
end
