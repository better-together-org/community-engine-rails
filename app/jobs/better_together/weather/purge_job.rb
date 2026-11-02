# frozen_string_literal: true

module BetterTogether
  module Weather
    # Daily retention pass over stored observations and superseded forecasts.
    class PurgeJob < ApplicationJob
      queue_as :maintenance

      def perform(dry_run: false)
        result = Retention.new(dry_run: dry_run).call
        Rails.logger.info("[Weather::PurgeJob] #{result.to_json}")
        result
      end
    end
  end
end
