# frozen_string_literal: true

require 'json'

namespace :better_together do
  namespace :metrics do
    desc 'Apply retention windows to raw metrics and generated report exports'
    task retention: :environment do
      raw_metrics_days = ENV.fetch('RAW_METRICS_DAYS',
                                   BetterTogether::Metrics::RetentionService::DEFAULT_RAW_METRICS_DAYS)
      report_days = ENV.fetch('REPORT_DAYS', BetterTogether::Metrics::RetentionService::DEFAULT_REPORT_DAYS)
      dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil))

      summary = BetterTogether::Metrics::RetentionService.new(
        raw_metrics_days: raw_metrics_days,
        report_days: report_days,
        dry_run: dry_run
      ).call

      puts JSON.pretty_generate(summary)
    end
  end
end
