# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Applies retention windows to raw metrics and generated report exports.
    class RetentionService
      DEFAULT_RAW_METRICS_DAYS = 180
      DEFAULT_REPORT_DAYS = 90

      RAW_METRIC_MODELS = {
        'page_views' => [BetterTogether::Metrics::PageView, :viewed_at],
        'link_clicks' => [BetterTogether::Metrics::LinkClick, :clicked_at],
        'shares' => [BetterTogether::Metrics::Share, :shared_at],
        'downloads' => [BetterTogether::Metrics::Download, :downloaded_at],
        'search_queries' => [BetterTogether::Metrics::SearchQuery, :searched_at]
      }.freeze

      REPORT_MODELS = {
        'page_view_reports' => BetterTogether::Metrics::PageViewReport,
        'link_click_reports' => BetterTogether::Metrics::LinkClickReport,
        'link_checker_reports' => BetterTogether::Metrics::LinkCheckerReport,
        'user_account_reports' => BetterTogether::Metrics::UserAccountReport
      }.freeze

      def initialize(raw_metrics_days: DEFAULT_RAW_METRICS_DAYS, report_days: DEFAULT_REPORT_DAYS, dry_run: false)
        @raw_metrics_days = Integer(raw_metrics_days)
        @report_days = Integer(report_days)
        @dry_run = dry_run
      end

      def call
        {
          dry_run: @dry_run,
          raw_metrics_days: @raw_metrics_days,
          report_days: @report_days,
          raw_metrics_cutoff: raw_metrics_cutoff.iso8601,
          reports_cutoff: reports_cutoff.iso8601,
          raw_metrics: apply_raw_metrics_retention,
          reports: apply_report_retention
        }
      end

      private

      def raw_metrics_cutoff
        @raw_metrics_cutoff ||= @raw_metrics_days.days.ago
      end

      def reports_cutoff
        @reports_cutoff ||= @report_days.days.ago
      end

      def apply_raw_metrics_retention
        RAW_METRIC_MODELS.transform_values do |(model, timestamp_column)|
          relation = model.where(model.arel_table[timestamp_column].lt(raw_metrics_cutoff))
          eligible_count = relation.count

          {
            eligible_count: eligible_count,
            deleted_count: @dry_run ? 0 : relation.in_batches.delete_all
          }
        end
      end

      def apply_report_retention
        REPORT_MODELS.transform_values do |model|
          relation = model.where(model.arel_table[:created_at].lt(reports_cutoff))
          eligible_count = relation.count

          deleted_count = @dry_run ? 0 : delete_reports(relation)

          {
            eligible_count: eligible_count,
            deleted_count: deleted_count
          }
        end
      end

      def delete_reports(relation)
        relation.find_each.count(&:destroy!)
      end
    end
  end
end
