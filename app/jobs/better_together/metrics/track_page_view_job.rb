# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackPageViewJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(pageable, locale)
        BetterTogether::Metrics::PageView.create!(
          pageable:,
          viewed_at: Time.current,
          locale:
        )
      end
    end
  end
end
