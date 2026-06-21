# frozen_string_literal: true

module BetterTogether
  module Safety
    # Refreshes the deterministic local review snapshot so scheduled local jobs can
    # keep safety triage useful when remote analysis is unavailable.
    class LocalReviewSnapshotJob < ApplicationJob
      queue_as :default

      def perform
        Rails.cache.write(
          BetterTogether::Safety::LocalReviewSnapshotService::CACHE_KEY,
          BetterTogether::Safety::LocalReviewSnapshotService.new.call,
          expires_in: 15.minutes
        )
      end
    end
  end
end
