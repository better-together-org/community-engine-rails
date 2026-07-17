# frozen_string_literal: true

# app/jobs/better_together/metrics/track_download_job.rb
module BetterTogether
  module Metrics
    class TrackDownloadJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(downloadable, file_name, file_type, file_size, locale, platform_id = nil, logged_in = false) # rubocop:todo Metrics/ParameterLists,Style/OptionalBooleanParameter
        # Prefer the downloadable's own platform (the real content owner) over the
        # viewer's current platform context — they can differ for federated/
        # cross-platform content, and the caller-supplied platform_id only reflects
        # who was browsing, not what they downloaded.
        resolved_platform_id = downloadable.try(:platform_id) || platform_id

        BetterTogether::Metrics::Download.create!(
          downloadable:, # Polymorphic resource
          file_name:,            # File name
          file_type:,            # Content type
          file_size:,            # File size in bytes
          locale:, # Locale
          downloaded_at: Time.current, # Time of download
          platform_id: resolved_platform_id,
          logged_in:
        )
      end
    end
  end
end
