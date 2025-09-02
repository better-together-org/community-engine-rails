# frozen_string_literal: true

require 'net/http'
require 'uri'

module BetterTogether
  module Metrics
    class InternalLinkCheckerJob < ApplicationJob
      queue_as :default

      def perform(link_id)
        link = BetterTogether::Content::Link.find(link_id)
        uri = URI.parse(link.url)
        response = http_head(uri)

        link.update!(last_checked_at: Time.current, latest_status_code: response.code.to_s, valid_link: response.is_a?(Net::HTTPSuccess))
      rescue StandardError => e
        link.update!(last_checked_at: Time.current, latest_status_code: nil, valid_link: false,
                     error_message: e.message)
      end

      private

      def http_head(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5) do |http|
          request = Net::HTTP::Head.new(uri.request_uri)
          http.request(request)
        end
      end
    end
  end
end
