# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Controller for metrics reports and chart data endpoints
    class ReportsController < ApplicationController # rubocop:disable Metrics/ClassLength
      include DatetimeFilterable

      # Predefined colors for known viewable types
      VIEWABLE_TYPE_COLORS = {
        'BetterTogether::Page' => { r: 75, g: 192, b: 192 },           # Teal
        'BetterTogether::Post' => { r: 153, g: 102, b: 255 },          # Purple
        'BetterTogether::Community' => { r: 255, g: 159, b: 64 },      # Orange
        'BetterTogether::Event' => { r: 255, g: 99, b: 132 },          # Red
        'BetterTogether::EventCategory' => { r: 255, g: 105, b: 180 }, # Hot Pink
        'BetterTogether::Person' => { r: 54, g: 162, b: 235 },         # Blue
        'BetterTogether::Platform' => { r: 255, g: 206, b: 86 },       # Yellow
        'BetterTogether::Joatu::Offer' => { r: 75, g: 192, b: 75 },    # Green
        'BetterTogether::Joatu::Request' => { r: 192, g: 75, b: 192 }, # Magenta
        'BetterTogether::Joatu::Agreement' => { r: 100, g: 149, b: 237 }, # Cornflower
        'BetterTogether::Joatu::Category' => { r: 34, g: 139, b: 34 }, # Forest Green
        'BetterTogether::Category' => { r: 46, g: 125, b: 50 },        # Dark Green
        'BetterTogether::Checklist' => { r: 216, g: 67, b: 21 }        # Deep Orange
      }.freeze

      before_action :authorize_metrics_access
      before_action :set_min_dates, only: :index
      before_action :set_metrics_data, only: :index

      # Main dashboard view - loads initial state with default date range
      def index; end

      # JSON endpoint for page views grouped by URL and pageable_type (stacked bar chart)
      def page_views_by_url_data # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        scope = filter_by_datetime(BetterTogether::Metrics::PageView, :viewed_at)
        views_by_url_and_type = scope.group(:page_url, :pageable_type).count

        pageable_types = scope.distinct.pluck(:pageable_type).compact
        urls = views_by_url_and_type.keys.map { |(url, _type)| url }.uniq.sort_by do |url|
          -views_by_url_and_type.select do |(u, _t), _count|
            u == url
          end.values.sum
        end.take(20)

        datasets = pageable_types.map do |pageable_type|
          {
            label: localized_model_name(pageable_type),
            backgroundColor: viewable_type_color(pageable_type),
            data: urls.map { |url| views_by_url_and_type.fetch([url, pageable_type], 0) }
          }
        end

        render json: { labels: urls, datasets: datasets }
      end

      # JSON endpoint for daily page views grouped by pageable_type (stacked line chart)
      def page_views_daily_data # rubocop:disable Metrics/AbcSize
        scope = filter_by_datetime(BetterTogether::Metrics::PageView, :viewed_at)
        views_by_day_and_type = scope.group_by_day(:viewed_at).group(:pageable_type).count

        pageable_types = scope.distinct.pluck(:pageable_type).compact
        days = views_by_day_and_type.keys.map { |(day, _type)| day }.uniq.sort

        datasets = pageable_types.map do |pageable_type|
          {
            label: localized_model_name(pageable_type),
            backgroundColor: viewable_type_color(pageable_type),
            borderColor: viewable_type_color(pageable_type, border: true),
            data: days.map { |day| views_by_day_and_type.fetch([day, pageable_type], 0) },
            fill: true
          }
        end

        render json: { labels: days.map(&:to_s), datasets: datasets }
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

      # JSON endpoint for top search queries by term
      def search_queries_by_term_data
        scope = filter_by_datetime(BetterTogether::Metrics::SearchQuery, :searched_at)
        search_counts = scope.group(:query).order('count_all DESC').limit(20).count
        avg_results = calculate_average_results(scope, search_counts.keys)
        avg_results_array = search_counts.keys.map { |query| avg_results[query] || 0 }
        thresholds = BetterTogether::Metrics.generate_result_levels(avg_results_array)

        render json: {
          labels: search_counts.keys,
          values: search_counts.values,
          avgResults: avg_results_array,
          thresholds: thresholds
        }
      end

      # JSON endpoint for daily search queries
      def search_queries_daily_data
        scope = filter_by_datetime(BetterTogether::Metrics::SearchQuery, :searched_at)
        data = scope.group_by_day(:searched_at).count

        render json: { labels: data.keys.map(&:to_s), values: data.values }
      end

      # JSON endpoint for daily user account creation and confirmation
      def user_accounts_daily_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        users_scope = filter_by_datetime(BetterTogether::User, :created_at)

        created_by_day = users_scope.group_by_day(:created_at).count
        confirmed_by_day = users_scope.where.not(confirmed_at: nil)
                                      .group_by_day(:confirmed_at)
                                      .count

        days = (@start_date.to_date..@end_date.to_date).to_a

        datasets = [
          {
            label: I18n.t('better_together.metrics.reports.charts.accounts_created', default: 'Accounts Created'),
            backgroundColor: 'rgba(54, 162, 235, 0.2)',
            borderColor: 'rgba(54, 162, 235, 1)',
            data: days.map { |day| created_by_day.fetch(day, 0) },
            fill: true
          },
          {
            label: I18n.t('better_together.metrics.reports.charts.accounts_confirmed', default: 'Accounts Confirmed'),
            backgroundColor: 'rgba(75, 192, 192, 0.2)',
            borderColor: 'rgba(75, 192, 192, 1)',
            data: days.map { |day| confirmed_by_day.fetch(day, 0) },
            fill: true
          }
        ]

        render json: { labels: days.map(&:to_s), datasets: datasets }
      end

      # JSON endpoint for confirmation rate trend
      def user_confirmation_rate_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        users_scope = filter_by_datetime(BetterTogether::User, :created_at)

        created_by_day = users_scope.group_by_day(:created_at).count

        days = (@start_date.to_date..@end_date.to_date).to_a
        confirmation_rates = days.map do |day|
          created_count = created_by_day.fetch(day, 0)
          if created_count.zero?
            0
          else
            confirmed_count = users_scope.where(created_at: day.beginning_of_day..day.end_of_day)
                                         .where.not(confirmed_at: nil)
                                         .count
            ((confirmed_count.to_f / created_count) * 100).round(2)
          end
        end

        render json: {
          labels: days.map(&:to_s),
          values: confirmation_rates
        }
      end

      # JSON endpoint for registration sources breakdown
      def user_registration_sources_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        users_scope = filter_by_datetime(BetterTogether::User, :created_at)

        # Get all user IDs in scope
        all_user_ids = users_scope.pluck(:id)

        # Find users who accepted invitations (via person's invitee relationship)
        identifications = BetterTogether::Identification.arel_table
        invitations = BetterTogether::Invitation.arel_table

        invitation_user_ids = BetterTogether::Identification
                              .where(active: true)
                              .where(agent_type: 'BetterTogether::User')
                              .where(agent_id: all_user_ids)
                              .where(identity_type: 'BetterTogether::Person')
                              .joins(
                                Arel::Nodes::InnerJoin.new(
                                  invitations,
                                  Arel::Nodes::On.new(
                                    invitations[:invitee_id].eq(identifications[:identity_id])
                                    .and(invitations[:invitee_type].eq('BetterTogether::Person'))
                                    .and(invitations[:status].eq('accepted'))
                                  )
                                )
                              )
                              .pluck(:agent_id)
                              .uniq

        # Find users with OAuth integrations (via person's platform integrations)
        platform_integrations = BetterTogether::PersonPlatformIntegration.arel_table

        oauth_user_ids = BetterTogether::Identification
                         .where(active: true)
                         .where(agent_type: 'BetterTogether::User')
                         .where(agent_id: all_user_ids)
                         .where(identity_type: 'BetterTogether::Person')
                         .joins(
                           Arel::Nodes::InnerJoin.new(
                             platform_integrations,
                             Arel::Nodes::On.new(
                               platform_integrations[:person_id].eq(identifications[:identity_id])
                             )
                           )
                         )
                         .pluck(:agent_id)
                         .uniq

        invitation_users = invitation_user_ids.length
        oauth_users = oauth_user_ids.length

        # Users without invitations or OAuth are open registration
        special_user_ids = (invitation_user_ids + oauth_user_ids).uniq
        open_registration_users = (all_user_ids - special_user_ids).count

        labels = [
          I18n.t('better_together.metrics.reports.charts.open_registration', default: 'Open Registration'),
          I18n.t('better_together.metrics.reports.charts.invitation', default: 'Invitation'),
          I18n.t('better_together.metrics.reports.charts.oauth', default: 'OAuth/Social')
        ]

        values = [open_registration_users, invitation_users, oauth_users]

        render json: {
          labels: labels,
          values: values
        }
      end

      # JSON endpoint for cumulative user growth
      def user_cumulative_growth_data # rubocop:disable Metrics/AbcSize
        users_scope = filter_by_datetime(BetterTogether::User, :created_at)
        created_by_day = users_scope.group_by_day(:created_at).count

        days = (@start_date.to_date..@end_date.to_date).to_a
        cumulative_total = 0
        cumulative_data = days.map do |day|
          cumulative_total += created_by_day.fetch(day, 0)
          cumulative_total
        end

        render json: {
          labels: days.map(&:to_s),
          values: cumulative_data
        }
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

        # Build datasets with colors for Chart.js pie chart
        datasets = [{
          label: 'Shares by Platform',
          data: data.values,
          backgroundColor: data.keys.map { |platform| platform_color(platform) },
          borderColor: data.keys.map { |platform| platform_color(platform, border: true) },
          borderWidth: 1
        }]

        render json: { labels: data.keys, datasets: datasets }
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

      # Helper method to generate consistent colors for platforms
      def platform_color(platform, border: false)
        random_color_for_platform(platform, border: border)
      end

      def random_color_for_platform(platform, border: false)
        opacity = border ? '1' : '0.5'
        colors = {
          'facebook' => "rgba(59, 89, 152, #{opacity})",
          'bluesky' => "rgba(29, 161, 242, #{opacity})",
          'linkedin' => "rgba(0, 123, 182, #{opacity})",
          'pinterest' => "rgba(189, 8, 28, #{opacity})",
          'reddit' => "rgba(255, 69, 0, #{opacity})",
          'whatsapp' => "rgba(37, 211, 102, #{opacity})"
        }
        colors[platform] || "rgba(75, 192, 192, #{opacity})"
      end

      private

      def authorize_metrics_access
        authorize :report, :index?, policy_class: BetterTogether::Metrics::ReportPolicy
      end

      # Set minimum dates for each metric type
      # rubocop:disable Metrics/AbcSize
      def set_min_dates # rubocop:disable Metrics/CyclomaticComplexity
        @min_dates = {
          page_views: (BetterTogether::Metrics::PageView.minimum(:viewed_at) || 1.year.ago) - 1.day,
          link_clicks: (BetterTogether::Metrics::LinkClick.minimum(:clicked_at) || 1.year.ago) - 1.day,
          downloads: (BetterTogether::Metrics::Download.minimum(:downloaded_at) || 1.year.ago) - 1.day,
          shares: (BetterTogether::Metrics::Share.minimum(:shared_at) || 1.year.ago) - 1.day,
          link_checker: (BetterTogether::Content::Link.minimum(:created_at) || 1.year.ago) - 1.day,
          search_queries: (BetterTogether::Metrics::SearchQuery.minimum(:searched_at) || 1.year.ago) - 1.day,
          user_accounts: (BetterTogether::User.minimum(:created_at) || 1.year.ago) - 1.day
        }
      end
      # rubocop:enable Metrics/AbcSize

      # Set metrics data for index action
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def set_metrics_data
        # Page views
        @page_views_by_url = BetterTogether::Metrics::PageView.group(:page_url).count
        @page_views_daily = BetterTogether::Metrics::PageView.group_by_day(:viewed_at).count

        # Link clicks
        @link_clicks_by_url = BetterTogether::Metrics::LinkClick.group(:url).count
        @link_clicks_daily = BetterTogether::Metrics::LinkClick.group_by_day(:clicked_at).count
        @internal_vs_external = BetterTogether::Metrics::LinkClick.group(:internal).count
        @link_clicks_by_page = BetterTogether::Metrics::LinkClick.group(:page_url).count

        # Downloads
        @downloads_by_file = BetterTogether::Metrics::Download.group(:file_name).count

        # Shares
        @shares_by_platform = BetterTogether::Metrics::Share.group(:platform).count
        @shares_by_url_and_platform = BetterTogether::Metrics::Share.group(:url, :platform).count

        # Prepare shares data for Chart.js
        urls = @shares_by_url_and_platform.keys.map(&:first).uniq
        platforms = @shares_by_url_and_platform.keys.map(&:last).uniq

        @shares_data = {
          labels: urls,
          datasets: platforms.map do |platform|
            {
              label: platform.titleize,
              backgroundColor: platform_color(platform),
              data: urls.map { |url| @shares_by_url_and_platform[[url, platform]] || 0 }
            }
          end
        }

        # Links
        @links_by_host = BetterTogether::Content::Link.group(:host).count
        @invalid_by_host = BetterTogether::Content::Link.where(valid_link: false).group(:host).count
        @failures_daily = BetterTogether::Content::Link.where(valid_link: false).group_by_day(:last_checked_at).count
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Calculate average results for search queries
      def calculate_average_results(scope, queries)
        scope.where(query: queries)
             .group(:query)
             .average(:results_count)
             .transform_values { |v| v.to_f.round(1) }
      end

      # Helper method to generate consistent colors for viewable types
      def viewable_type_color(viewable_type, border: false)
        opacity = border ? '1' : '0.5'

        # Return predefined color if available
        if VIEWABLE_TYPE_COLORS[viewable_type]
          color = VIEWABLE_TYPE_COLORS[viewable_type]
          return "rgba(#{color[:r]}, #{color[:g]}, #{color[:b]}, #{opacity})"
        end

        # Generate color for unknown types using hash-based color generation
        # This ensures the same type always gets the same color
        type_hash = viewable_type.hash.abs
        hue = (type_hash % 360)
        saturation = 65 + (type_hash % 20)  # 65-85%
        lightness = 55 + (type_hash % 15)   # 55-70%

        "rgba(#{hsl_to_rgb(hue, saturation, lightness, opacity)})"
      end

      # Convert HSL to RGB for dynamic color generation
      def hsl_to_rgb(hue, saturation, lightness, opacity)
        hue_normalized = hue / 360.0
        sat_normalized = saturation / 100.0
        light_normalized = lightness / 100.0

        red, green, blue = if sat_normalized.zero?
                             grayscale_rgb(light_normalized)
                           else
                             color_rgb(hue_normalized, sat_normalized, light_normalized)
                           end

        "#{red}, #{green}, #{blue}, #{opacity}"
      end

      # Calculate grayscale RGB values
      def grayscale_rgb(light_normalized)
        value = (light_normalized * 255).round
        [value, value, value]
      end

      # Calculate color RGB values from HSL
      def color_rgb(hue_normalized, sat_normalized, light_normalized)
        max_value = calculate_max_value(light_normalized, sat_normalized)
        min_value = (2 * light_normalized) - max_value

        red = (hue_to_rgb(min_value, max_value, hue_normalized + (1.0 / 3)) * 255).round
        green = (hue_to_rgb(min_value, max_value, hue_normalized) * 255).round
        blue = (hue_to_rgb(min_value, max_value, hue_normalized - (1.0 / 3)) * 255).round

        [red, green, blue]
      end

      # Calculate max value for HSL to RGB conversion
      def calculate_max_value(light_normalized, sat_normalized)
        if light_normalized < 0.5
          light_normalized * (1 + sat_normalized)
        else
          light_normalized + sat_normalized - (light_normalized * sat_normalized)
        end
      end

      # Helper for HSL to RGB conversion
      # rubocop:disable Naming/MethodParameterName
      def hue_to_rgb(min_value, max_value, hue_value)
        hue_value += 1 if hue_value.negative?
        hue_value -= 1 if hue_value > 1
        return min_value + ((max_value - min_value) * 6 * hue_value) if hue_value < 1.0 / 6
        return max_value if hue_value < 1.0 / 2
        return min_value + ((max_value - min_value) * ((2.0 / 3) - hue_value) * 6) if hue_value < 2.0 / 3

        min_value
      end
      # rubocop:enable Naming/MethodParameterName

      # Helper method to get localized model name
      def localized_model_name(model_class_name)
        return I18n.t('better_together.metrics.reports.unknown_type') if model_class_name.blank?

        begin
          model_class_name.constantize.model_name.human(count: 2)
        rescue NameError
          model_class_name.demodulize
        end
      end
    end
  end
end
