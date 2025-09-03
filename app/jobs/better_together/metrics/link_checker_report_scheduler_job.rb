# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Scheduler job to create and send LinkChecker reports
    class LinkCheckerReportSchedulerJob < MetricsJob
      def perform(from_date: nil, to_date: nil, file_format: 'csv')
        report = BetterTogether::Metrics::LinkCheckerReport.create_and_generate!(
          from_date: from_date,
          to_date: to_date,
          file_format: file_format
        )

        return unless report.report_file.attached?

        BetterTogether::Metrics::ReportMailer.link_checker_report(report.id).deliver_later
      end
    end
  end
end
