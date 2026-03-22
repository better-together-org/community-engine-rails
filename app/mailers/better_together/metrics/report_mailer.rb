# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Mailer for delivering metrics reports
    class ReportMailer < BetterTogether::ApplicationMailer
      def link_checker_report(report_id)
        @report = BetterTogether::Metrics::LinkCheckerReport.find(report_id)
        return unless @report&.report_file&.attached?

        attach_report_file
        mail(
          to: BetterTogether::ApplicationMailer.default[:from],
          subject: build_report_subject
        )
      end

      private

      def attach_report_file
        attachments[@report.report_file.filename.to_s] = {
          mime_type: @report.report_file.content_type,
          content: @report.report_file.download
        }
      end

      def build_report_subject
        I18n.t(
          'better_together.metrics.mailer.link_checker_report.subject',
          date: @report.created_at.strftime('%Y-%m-%d'),
          count: @report.total_broken_links
        )
      end
    end
  end
end
