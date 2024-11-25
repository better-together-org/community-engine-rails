# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackLinkClickJob < MetricsJob
      def perform(url, page_url, locale, internal)
        BetterTogether::Metrics::LinkClick.create!(
          url: url,
          page_url: page_url, # Save the page URL where the link was clicked
          locale: locale,
          internal: internal,
          clicked_at: Time.current
        )
      end
    end
  end
end
