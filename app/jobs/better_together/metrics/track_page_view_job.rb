module BetterTogether
  module Metrics
    class TrackPageViewJob < MetricsJob
      def perform(pageable, locale)
        BetterTogether::Metrics::PageView.create!(
          pageable: pageable,
          viewed_at: Time.current,
          locale: locale
        )
      end
    end
  end
end
