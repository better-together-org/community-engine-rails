# frozen_string_literal: true

module BetterTogether
  module Weather
    # Daily scan that enqueues a history backfill for every active location.
    class BackfillScanJob < BaseJob
      def perform
        Location.active.select(:id).find_each do |location|
          BackfillLocationJob.perform_later(location.id)
        end
      end
    end
  end
end
