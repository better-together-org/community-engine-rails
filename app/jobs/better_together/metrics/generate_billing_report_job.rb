# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Builds the CSV of a saved billing report and attaches it, then tells its creator the file is ready (the same
    # channel and message the other metrics reports use, with the row to update named in the message).
    class GenerateBillingReportJob < ApplicationJob
      queue_as :metrics

      def perform(report_id)
        report = BillingReport.find(report_id)

        report.report_file.attach(io: StringIO.new(Billing::TaxReport::Csv.generate(report.report_data)),
                                  filename: filename(report), content_type: 'text/csv')
        broadcast_file_ready(report)
      end

      private

      def broadcast_file_ready(report)
        return unless report.creator

        UserAccountReportsChannel.broadcast_to(
          report.creator,
          { report_id: report.id, row_id: "billing_report_#{report.id}", file_ready: true,
            download_url: BetterTogether::Engine.routes.url_helpers.download_metrics_billing_report_path(report, locale: I18n.default_locale) }
        )
      end

      def filename(report)
        "billing_report_#{report.filter('from_date')}_to_#{report.filter('to_date')}_#{Time.current.to_i}.csv"
      end
    end
  end
end
