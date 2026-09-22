# frozen_string_literal: true

module BetterTogether
  module Safety
    # Refreshes the deterministic local review snapshot so scheduled local jobs can
    # keep safety triage useful when remote analysis is unavailable.
    class LocalReviewSnapshotJob < ApplicationJob
      queue_as :default

      def perform
        BetterTogether::Platform.find_each { |platform| refresh_snapshot_for(platform) }
      end

      private

      def refresh_snapshot_for(platform)
        Rails.cache.write(
          BetterTogether::Safety::LocalReviewSnapshotService.cache_key_for(platform),
          BetterTogether::Safety::LocalReviewSnapshotService.new(
            case_scope: BetterTogether::Safety::Case.for_platform(platform),
            report_scope: BetterTogether::Report.for_platform(platform),
            content_security_subject_scope: BetterTogether::ContentSecurity::Subject.for_platform(platform)
          ).call,
          expires_in: 15.minutes
        )
      end
    end
  end
end
