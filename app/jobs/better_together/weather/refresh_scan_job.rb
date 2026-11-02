# frozen_string_literal: true

module BetterTogether
  module Weather
    # Hourly scan that enqueues a refresh for every enabled location of an enabled source.
    class RefreshScanJob < ApplicationJob
      queue_as :weather

      def perform
        Location.enabled.where(source_id: Source.enabled.select(:id)).find_each do |location|
          RefreshLocationJob.perform_later(location.id)
        end
      end
    end
  end
end
