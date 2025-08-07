# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackSearchQueryJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(query, results_count, locale)
        BetterTogether::Metrics::SearchQuery.create!(
          query: query,
          results_count: results_count,
          locale: locale,
          searched_at: Time.current
        )
      end
    end
  end
end
