# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Mailer for delivering metrics reports
    class ReportMailer < BetterTogether::ApplicationMailer
      # rubocop:todo Metrics/AbcSize
      def link_checker_report(report_id)
        @report = BetterTogether::Metrics::LinkCheckerReport.find(report_id)
        return unless @report&.report_file&.attached?

        attachments[@report.report_file.filename.to_s] = {
          mime_type: @report.report_file.content_type,
          content: @report.report_file.download
        }

        broken_count = @report.total_broken_links

        mail(
          to: BetterTogether::ApplicationMailer.default[:from],
          subject: I18n.t(
            'better_together.metrics.mailer.link_checker_report.subject',
            date: @report.created_at.strftime('%Y-%m-%d'),
            count: broken_count
          )
        )
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
