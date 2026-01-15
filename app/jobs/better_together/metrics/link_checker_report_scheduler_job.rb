# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Scheduler job to create and send LinkChecker reports
    # Only sends email if there are new broken links or changes since last report
    class LinkCheckerReportSchedulerJob < MetricsJob
      def perform(from_date: nil, to_date: nil, file_format: 'csv')
        report = BetterTogether::Metrics::LinkCheckerReport.create_and_generate!(
          from_date: from_date,
          to_date: to_date,
          file_format: file_format
        )

        return unless report.report_file.attached?
        return unless should_send_email?(report)

        BetterTogether::Metrics::ReportMailer.link_checker_report(report.id).deliver_later
      end

      private

      def should_send_email?(current_report)
        # Always send if there are no broken links data (empty report)
        return false if current_report.has_no_broken_links?

        # Find the most recent previous report (excluding the current one)
        previous_report = BetterTogether::Metrics::LinkCheckerReport
                          .where.not(id: current_report.id)
                          .order(created_at: :desc)
                          .first

        # Send email if this is the first report ever
        return true if previous_report.nil?

        # Send email if the broken links have changed
        current_report.broken_links_changed_since?(previous_report)
      end
    end
  end
end
