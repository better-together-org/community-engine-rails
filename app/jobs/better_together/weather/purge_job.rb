# frozen_string_literal: true

module BetterTogether
  module Weather
    # Daily retention pass over stored observations and superseded forecasts. It also runs
    # without a source while old readings remain, and is skipped when nothing is stored.
    class PurgeJob < BaseJob
      queue_as :maintenance

      def self.work_available?
        Weather.data_stored?
      end

      def perform(dry_run: false)
        result = Retention.new(dry_run: dry_run).call
        Rails.logger.info("[Weather::PurgeJob] #{result.to_json}")
        result
      end
    end
  end
end
