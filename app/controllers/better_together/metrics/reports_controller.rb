# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Controller for metrics reports and chart data endpoints
    class ReportsController < ApplicationController
      include DatetimeFilterable

      before_action :authorize_metrics_access
      before_action :set_min_dates, only: :index

      # Main dashboard view - loads initial state with default date range
      def index; end

      # JSON endpoint for page views grouped by URL
      def page_views_by_url_data
        scope = filter_by_datetime(BetterTogether::Metrics::PageView, :viewed_at)
        data = scope.group(:page_url).order('count_all DESC').limit(20).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for daily page views
      def page_views_daily_data
        scope = filter_by_datetime(BetterTogether::Metrics::PageView, :viewed_at)
        data = scope.group_by_day(:viewed_at).count

        render json: { labels: data.keys.map(&:to_s), values: data.values }
      end

      # JSON endpoint for link clicks grouped by URL
      def link_clicks_by_url_data
        scope = filter_by_datetime(BetterTogether::Metrics::LinkClick, :clicked_at)
        data = scope.group(:url).order('count_all DESC').limit(20).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for daily link clicks
      def link_clicks_daily_data
        scope = filter_by_datetime(BetterTogether::Metrics::LinkClick, :clicked_at)
        data = scope.group_by_day(:clicked_at).count

        render json: { labels: data.keys.map(&:to_s), values: data.values }
      end

      # JSON endpoint for downloads grouped by file name
      def downloads_by_file_data
        scope = filter_by_datetime(BetterTogether::Metrics::Download, :downloaded_at)
        data = scope.group(:file_name).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for shares grouped by platform
      def shares_by_platform_data
        scope = filter_by_datetime(BetterTogether::Metrics::Share, :shared_at)
        data = scope.group(:platform).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for shares grouped by URL and platform (stacked bar chart)
      def shares_by_url_and_platform_data
        scope = filter_by_datetime(BetterTogether::Metrics::Share, :shared_at)
        shares_by_url_and_platform = scope.group(:url, :platform).count

        platforms = scope.distinct.pluck(:platform)
        urls = shares_by_url_and_platform.keys.map { |(url, _platform)| url }.uniq

        datasets = platforms.map do |platform|
          {
            label: platform.capitalize,
            backgroundColor: platform_color(platform),
            data: urls.map { |url| shares_by_url_and_platform.fetch([url, platform], 0) }
          }
        end

        render json: { labels: urls, datasets: datasets }
      end

      # JSON endpoint for links grouped by host
      def links_by_host_data
        scope = BetterTogether::Content::Link.all
        scope = scope.where(created_at: @start_date..@end_date) if @start_date && @end_date
        data = scope.group(:host).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for invalid links grouped by host
      def invalid_by_host_data
        scope = BetterTogether::Content::Link.where(valid_link: false)
        scope = scope.where(created_at: @start_date..@end_date) if @start_date && @end_date
        data = scope.group(:host).count

        render json: { labels: data.keys, values: data.values }
      end

      # JSON endpoint for daily invalid links
      def failures_daily_data
        scope = BetterTogether::Content::Link.where(valid_link: false)
        scope = scope.where(last_checked_at: @start_date..@end_date) if @start_date && @end_date
        data = scope.group_by_day(:last_checked_at).count

        render json: { labels: data.keys.map(&:to_s), values: data.values }
      end

      private

      def authorize_metrics_access
        authorize %i[metrics report], :index?, policy_class: BetterTogether::Metrics::ReportPolicy
      end

      # Set minimum dates for each metric type
      # rubocop:disable Metrics/AbcSize
      def set_min_dates
        @min_dates = {
          page_views: (BetterTogether::Metrics::PageView.minimum(:viewed_at) || 1.year.ago) - 1.day,
          link_clicks: (BetterTogether::Metrics::LinkClick.minimum(:clicked_at) || 1.year.ago) - 1.day,
          downloads: (BetterTogether::Metrics::Download.minimum(:downloaded_at) || 1.year.ago) - 1.day,
          shares: (BetterTogether::Metrics::Share.minimum(:shared_at) || 1.year.ago) - 1.day,
          link_checker: (BetterTogether::Content::Link.minimum(:created_at) || 1.year.ago) - 1.day
        }
      end
      # rubocop:enable Metrics/AbcSize

      # Helper method to generate consistent colors for platforms
      def platform_color(platform)
        colors = {
          'facebook' => 'rgba(59, 89, 152, 0.5)',
          'bluesky' => 'rgba(29, 161, 242, 0.5)',
          'linkedin' => 'rgba(0, 123, 182, 0.5)',
          'pinterest' => 'rgba(189, 8, 28, 0.5)',
          'reddit' => 'rgba(255, 69, 0, 0.5)',
          'whatsapp' => 'rgba(37, 211, 102, 0.5)'
        }
        colors[platform] || 'rgba(75, 192, 192, 0.5)'
      end
    end
  end
end
