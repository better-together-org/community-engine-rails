# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to get platform metrics summary
    # Requires manage_platform permission
    class GetMetricsSummaryTool < ApplicationTool
      description 'Get aggregated platform metrics summary including page views, top pages, and locale breakdown'

      arguments do
        optional(:from_date)
          .filled(:string)
          .description('Start date for metrics period (ISO 8601, e.g. 2025-01-01)')
        optional(:to_date)
          .filled(:string)
          .description('End date for metrics period (ISO 8601, e.g. 2025-12-31)')
      end

      # Get metrics summary with authorization
      # @param from_date [String, nil] Optional start date filter
      # @param to_date [String, nil] Optional end date filter
      # @return [String] JSON metrics summary
      def call(from_date: nil, to_date: nil)
        return auth_required_response unless current_user&.person&.permitted_to?('manage_platform')

        with_timezone_scope do
          scope = build_scope(from_date, to_date)
          result = JSON.generate(build_summary(scope))

          log_invocation('get_metrics_summary', { from_date: from_date, to_date: to_date }, result.bytesize)
          result
        end
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Platform manager access required' })
      end

      def build_scope(from_date, to_date)
        scope = BetterTogether::Metrics::PageView.all
        scope = scope.where('viewed_at >= ?', safe_parse_date(from_date)) if from_date.present? && safe_parse_date(from_date)
        scope = scope.where('viewed_at <= ?', safe_parse_date(to_date)) if to_date.present? && safe_parse_date(to_date)
        scope
      end

      # Safely parse a date string, returning nil on invalid input
      # @param value [String, nil] Date string in ISO 8601 format
      # @return [Date, nil]
      def safe_parse_date(value)
        return nil if value.blank?

        Date.parse(value)
      rescue ArgumentError
        nil
      end

      def build_summary(scope) # rubocop:disable Metrics/MethodLength
        {
          total_page_views: scope.count,
          unique_pages: scope.distinct.count(:page_url),
          views_by_locale: scope.group(:locale).count,
          top_pages: top_pages(scope),
          period_start: scope.minimum(:viewed_at)&.iso8601,
          period_end: scope.maximum(:viewed_at)&.iso8601
        }
      end

      def top_pages(scope)
        scope.group(:page_url)
             .order(Arel.sql('count(*) DESC'))
             .limit(20)
             .count
      end
    end
  end
end
