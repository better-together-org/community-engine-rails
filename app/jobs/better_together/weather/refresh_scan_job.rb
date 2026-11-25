# frozen_string_literal: true

module BetterTogether
  module Weather
    # Scan that enqueues a refresh for every active location. Enqueues are spread a few
    # seconds apart so many locations do not hit the source at the same moment.
    class RefreshScanJob < BaseJob
      STAGGER = 2.seconds

      def perform
        Location.active.select(:id).find_each.with_index do |location, index|
          RefreshLocationJob.set(wait: STAGGER * (index % 60)).perform_later(location.id)
        end
      end
    end
  end
end
