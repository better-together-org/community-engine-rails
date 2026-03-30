# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackLinkClickJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(url, page_url, locale, internal, platform_id, logged_in) # rubocop:todo Metrics/ParameterLists
        BetterTogether::Metrics::LinkClick.create!(
          url:,
          page_url:, # Save the page URL where the link was clicked
          locale:,
          internal:,
          clicked_at: Time.current,
          platform_id:,
          logged_in:
        )
      end
    end
  end
end
