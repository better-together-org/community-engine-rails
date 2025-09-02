# frozen_string_literal: true

require 'net/http'
require 'uri'

module BetterTogether
  module Metrics
    # Background job that checks an internal link's HTTP status and updates
    # the corresponding BetterTogether::Content::Link record with the
    # latest check timestamp, status code and validity flag.
    class InternalLinkCheckerJob < ApplicationJob
      queue_as :default

      def perform(link_id)
        link = BetterTogether::Content::Link.find(link_id)
        checker = BetterTogether::Metrics::HttpLinkChecker.new(link.url)
        result = checker.call

        update_link_from_result(link, result)
      end

      private

      def update_link_from_result(link, result)
        attrs = {
          last_checked_at: Time.current,
          latest_status_code: result.status_code,
          valid_link: result.success
        }

        attrs[:error_message] = result.error&.message unless result.success
        link.update!(attrs)
      end
    end
  end
end
