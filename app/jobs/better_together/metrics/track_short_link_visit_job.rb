# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackShortLinkVisitJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(payload)
        BetterTogether::Metrics::ShortLinkVisit.create!(visit_attributes(payload))
      end

      private

      def visit_attributes(payload) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        {
          short_link_id: payload['short_link_id'],
          platform_id: payload['platform_id'],
          referrer: payload['referrer'].to_s.truncate(2048).presence,
          user_agent_string: payload['user_agent'].to_s.truncate(255).presence,
          remote_addr: payload['remote_addr'],
          logged_in: payload['logged_in'] || false,
          potential_bot: bot_user_agent?(payload['user_agent']),
          visited_at: Time.zone.parse(payload['visited_at'])
        }
      end

      def bot_user_agent?(user_agent_string)
        return false if user_agent_string.blank?

        user_agent_string.match?(/bot|crawl|spider|slurp|facebookexternalhit/i)
      end
    end
  end
end
