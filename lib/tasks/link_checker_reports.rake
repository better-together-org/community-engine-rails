# frozen_string_literal: true

namespace :metrics do
  desc 'Generate and email a Link Checker report for the previous day'
  task link_checker_daily: :environment do
    yesterday = 1.day.ago.beginning_of_day.strftime('%Y-%m-%d')
    today = 1.day.ago.end_of_day.strftime('%Y-%m-%d')
    BetterTogether::Metrics::LinkCheckerReportSchedulerJob.perform_later(
      from_date: yesterday,
      to_date: today,
      file_format: 'csv'
    )

    puts "Enqueued LinkCheckerReportSchedulerJob for #{yesterday} -> #{today}"
  end
end
