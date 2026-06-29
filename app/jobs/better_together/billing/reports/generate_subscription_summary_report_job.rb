# frozen_string_literal: true

require 'csv'

module BetterTogether
  module Billing
    module Reports
      # Background job to generate CSV export for subscription summary reports.
      class GenerateSubscriptionSummaryReportJob < BillingReportJob
        def perform(report_id)
          report = SubscriptionSummaryReport.find(report_id)

          report.report_file.attach(
            io: StringIO.new(build_csv(report)),
            filename: build_filename(report),
            content_type: 'text/csv'
          )

          broadcast_file_ready(report)
        end

        private

        def broadcast_file_ready(report)
          return unless report.creator

          BetterTogether::Billing::Reports::SubscriptionSummaryReportsChannel.broadcast_to(
            report.creator,
            {
              report_id: report.id,
              file_ready: true
            }
          )
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def build_csv(report)
          CSV.generate(headers: true) do |csv|
            append_summary_section(csv, report.report_data['summary'])
            csv << []
            append_plan_breakdown_section(csv, report.report_data['plan_breakdown'])
            csv << []
            append_event_health_section(csv, report.report_data['event_health'])
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # rubocop:disable Metrics/AbcSize
        def append_summary_section(csv, summary)
          csv << ['Summary']
          csv << ['Date range (from)', summary['date_range']['from']]
          csv << ['Date range (to)', summary['date_range']['to']]
          csv << ['Active subscriptions', summary['active_subscription_count']]
          csv << ['New subscriptions (period)', summary['new_subscriptions']]
          csv << ['Churned subscriptions (period)', summary['churned_subscriptions']]
          csv << ['Current MRR (cents)', summary['current_mrr_cents']]
          csv << ['Current MRR ($)', format('%.2f', summary['current_mrr_cents'].to_f / 100)]
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/MethodLength
        def append_plan_breakdown_section(csv, breakdown)
          csv << ['Plan Breakdown']
          csv << ['Identifier', 'Name', 'Interval', 'Amount (cents)', 'Currency',
                  'Pricing tier', 'Active subs', 'MRR contribution (cents)']

          Array(breakdown).each do |row|
            csv << [
              row['identifier'],
              row['name'],
              row['billing_interval'],
              row['amount_cents'],
              row['currency'],
              row['pricing_tier'],
              row['active_subscription_count'],
              row['mrr_contribution_cents']
            ]
          end
        end
        # rubocop:enable Metrics/MethodLength

        def append_event_health_section(csv, health)
          csv << ['Event Health (period)']
          csv << ['Total events', health['total']]
          csv << ['Processed', health['processed']]
          csv << ['Pending', health['pending']]
          csv << ['Failed', health['failed']]
          csv << ['Dead-lettered', health['dead_lettered']]
          csv << ['Repeated failures', health['repeated_failures']]
        end

        def build_filename(report)
          from = report.filters['from_date'] || 30.days.ago.to_date
          to   = report.filters['to_date']   || Date.current
          "billing_subscription_summary_#{from}_to_#{to}_#{Time.current.to_i}.csv"
        end
      end
    end
  end
end
