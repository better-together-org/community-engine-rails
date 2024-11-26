# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackShareJob < MetricsJob
      def perform(platform, url, locale, shareable_type, shareable_id)
        shareable = shareable_type.constantize.find_by(id: shareable_id)

        # Create the Share record in the database
        BetterTogether::Metrics::Share.create!(
          platform:,
          url:,
          locale:,
          shared_at: Time.current,
          shareable:
        )
      end
    end
  end
end
