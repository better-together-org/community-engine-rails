# app/jobs/better_together/metrics/track_download_job.rb
module BetterTogether
  module Metrics
    class TrackDownloadJob < MetricsJob
      def perform(downloadable, file_name, file_type, file_size, locale)
        BetterTogether::Metrics::Download.create!(
          downloadable: downloadable,      # Polymorphic resource
          file_name: file_name,            # File name
          file_type: file_type,            # Content type
          file_size: file_size,            # File size in bytes
          locale: locale,                  # Locale
          downloaded_at: Time.current      # Time of download
        )
      end
    end
  end
end
