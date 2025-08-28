# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackShareJob < MetricsJob # rubocop:todo Style/Documentation
      # Only allow shares on specific, known models
      ALLOWED_SHAREABLES = %w[
        BetterTogether::Page
        BetterTogether::Event
        BetterTogether::Post
        BetterTogether::Community
      ].freeze

      def perform(platform, url, locale, shareable_type, shareable_id)
        shareable = nil
        if shareable_type.present?
          klass = BetterTogether::SafeClassResolver.resolve(shareable_type, allowed: ALLOWED_SHAREABLES)
          shareable = klass&.find_by(id: shareable_id)
        end

        # Create the Share record in the database
        # If a shareable_type was provided but is disallowed, do not create a record
        return if shareable_type.present? && shareable.nil?

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
