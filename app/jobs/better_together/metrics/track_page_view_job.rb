# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackPageViewJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(pageable, locale, platform_id = nil, logged_in = false) # rubocop:todo Style/OptionalBooleanParameter
        BetterTogether::Metrics::PageView.create!(
          pageable:,
          viewed_at: Time.current,
          locale:,
          platform_id:,
          logged_in:
        )
      end
    end
  end
end
