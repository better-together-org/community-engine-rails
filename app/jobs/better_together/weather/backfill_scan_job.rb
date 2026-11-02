# frozen_string_literal: true

module BetterTogether
  module Weather
    # Daily scan that enqueues a history backfill for every enabled location.
    class BackfillScanJob < ApplicationJob
      queue_as :weather

      def perform
        Location.enabled.where(source_id: Source.enabled.select(:id)).find_each do |location|
          BackfillLocationJob.perform_later(location.id)
        end
      end
    end
  end
end
