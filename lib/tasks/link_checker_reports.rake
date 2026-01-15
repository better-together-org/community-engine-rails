# frozen_string_literal: true

namespace :better_together do
  namespace :metrics do
    desc 'Generate and email a Link Checker report for the previous week'
    task link_checker_weekly: :environment do
      week_ago = 1.week.ago.beginning_of_week.strftime('%Y-%m-%d')
      week_end = 1.week.ago.end_of_week.strftime('%Y-%m-%d')
      BetterTogether::Metrics::LinkCheckerReportSchedulerJob.perform_later(
        from_date: week_ago,
        to_date: week_end,
        file_format: 'csv'
      )

      puts "Enqueued LinkCheckerReportSchedulerJob for #{week_ago} -> #{week_end}"
    end

    # Legacy task for backwards compatibility - now calls weekly
    desc 'Generate and email a Link Checker report for the previous day (deprecated - use link_checker_weekly)'
    task link_checker_daily: :environment do
      Rake::Task['better_together:metrics:link_checker_weekly'].invoke
    end
  end
end
