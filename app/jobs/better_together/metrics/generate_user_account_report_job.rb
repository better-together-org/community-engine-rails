# frozen_string_literal: true

require 'csv'

module BetterTogether
  module Metrics
    # Background job to generate CSV export for user account reports
    class GenerateUserAccountReportJob < ApplicationJob
      queue_as :metrics

      def perform(report_id)
        report = UserAccountReport.find(report_id)
        csv_content = build_csv(report)

        report.report_file.attach(
          io: StringIO.new(csv_content),
          filename: build_filename(report),
          content_type: 'text/csv'
        )

        # Broadcast to Action Cable that the file is ready
        broadcast_file_ready(report)
      end

      private

      def broadcast_file_ready(report)
        # Broadcast to the report creator's channel
        return unless report.creator

        Rails.logger.debug "[UserAccountReport] Broadcasting file_ready for report #{report.id} to creator #{report.creator.id}"

        BetterTogether::Metrics::UserAccountReportsChannel.broadcast_to(
          report.creator,
          {
            report_id: report.id,
            file_ready: true,
            download_url: BetterTogether::Engine.routes.url_helpers.download_metrics_user_account_report_path(
              report,
              locale: I18n.default_locale
            )
          }
        )

        Rails.logger.debug '[UserAccountReport] Broadcast complete'
      end

      def build_csv(report) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        CSV.generate(headers: true) do |csv| # rubocop:disable Metrics/BlockLength
          # Header row
          csv << ['Date', 'Accounts Created', 'Accounts Confirmed', 'Confirmation Rate (%)',
                  'Cumulative Created', 'Cumulative Confirmed']

          cumulative_created = 0
          cumulative_confirmed = 0

          # Data rows
          report.report_data['daily_stats'].each do |day|
            cumulative_created += day['accounts_created']
            cumulative_confirmed += day['accounts_confirmed']

            csv << [
              day['date'],
              day['accounts_created'],
              day['accounts_confirmed'],
              day['confirmation_rate'],
              cumulative_created,
              cumulative_confirmed
            ]
          end

          # Summary section
          csv << []
          csv << ['Summary']
          csv << ['Total Accounts Created', report.report_data['summary']['total_accounts_created']]
          csv << ['Total Accounts Confirmed', report.report_data['summary']['total_accounts_confirmed']]
          csv << ['Overall Confirmation Rate (%)', report.report_data['summary']['confirmation_rate']]

          # Registration sources
          csv << []
          csv << ['Registration Sources']
          sources = report.report_data['registration_sources']
          csv << ['Open Registration', sources['open_registration']]
          csv << ['Via Invitation', sources['invitation']]
          csv << ['Via OAuth', sources['oauth']]
        end
      end

      def build_filename(report)
        filters = report.filters
        from_date = filters['from_date'] || 30.days.ago.to_date
        to_date = filters['to_date'] || Date.current

        "user_account_report_#{from_date}_to_#{to_date}_#{Time.current.to_i}.csv"
      end
    end
  end
end
