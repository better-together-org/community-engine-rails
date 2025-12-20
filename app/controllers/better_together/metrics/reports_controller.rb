# frozen_string_literal: true

module BetterTogether
  module Metrics
    class ReportsController < ApplicationController # rubocop:todo Style/Documentation
      def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        authorize %i[metrics report], :index?, policy_class: BetterTogether::Metrics::ReportPolicy

        # Group Page Views by `page_url` and sort by `page_url`
        @page_views_by_url = BetterTogether::Metrics::PageView
                             .group(:page_url)
                             .order('count_all DESC')
                             .limit(20)
                             .count

        # Use group_by_day from groupdate to group daily Page Views, and sort them automatically by date
        @page_views_daily = BetterTogether::Metrics::PageView
                            .group_by_day(:viewed_at)
                            .count

        # Group Link Clicks by URL, sorting by URL first
        @link_clicks_by_url = BetterTogether::Metrics::LinkClick
                              .group(:url)
                              .order('count_all DESC')
                              .limit(20)
                              .count

        # Use group_by_day from groupdate to group daily Link Clicks, and sort them automatically by date
        @link_clicks_daily = BetterTogether::Metrics::LinkClick
                             .group_by_day(:clicked_at)
                             .count

        # Group Link Clicks by internal/external, sorted by internal status first
        @internal_vs_external = BetterTogether::Metrics::LinkClick
                                .group(:internal)
                                .count

        # Group Link Clicks by the page URL where the click occurred, sorted by `page_url`
        @link_clicks_by_page = BetterTogether::Metrics::LinkClick
                               .group(:page_url)
                               .count

        # Group Downloads by file name, sorted by file name first
        @downloads_by_file = BetterTogether::Metrics::Download
                             .group(:file_name)
                             .count

        # Group Shares by platform, sorted by platform first
        @shares_by_platform = BetterTogether::Metrics::Share
                              .group(:platform)
                              .count

        # Group Shares by both URL and Platform, sorted by URL and Platform first
        @shares_by_url_and_platform = BetterTogether::Metrics::Share
                                      .group(:url, :platform)
                                      .count

        # Transform the data for Chart.js
        platforms = BetterTogether::Metrics::Share.distinct.pluck(:platform)
        urls = @shares_by_url_and_platform.keys.map { |(url, _platform)| url }.uniq

        @shares_data = {
          labels: urls,
          datasets: platforms.map do |platform|
            {
              label: platform.capitalize,
              backgroundColor: random_color_for_platform(platform),
              data: urls.map { |url| @shares_by_url_and_platform.fetch([url, platform], 0) }
            }
          end
        }

        # Link Checker charts: aggregate data from stored links
        links_scope = BetterTogether::Content::Link.all
        @links_by_host = links_scope.group(:host).count
        @invalid_by_host = links_scope.where(valid_link: false).group(:host).count
        @failures_daily = links_scope.where(valid_link: false).group_by_day(:last_checked_at).count
      end

      # A helper method to generate a random color for each platform (this can be customized).
      def random_color_for_platform(platform)
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
