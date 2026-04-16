# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Controller for metrics reports and chart data endpoints
    class ReportsController < ApplicationController # rubocop:disable Metrics/ClassLength
      include DatetimeFilterable
      include PlatformContext

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
      EMPTY_REPORT_PAYLOADS = {
        empty_stacked_payload: %i[
          @page_views_by_url_chart_data
          @page_views_daily_chart_data
          @shares_by_platform_chart_data
          @shares_data
          @user_accounts_daily_chart_data
        ],
        empty_values_payload: %i[
          @link_clicks_by_url_chart_data
          @link_clicks_daily_chart_data
          @downloads_by_file_chart_data
          @links_by_host_chart_data
          @invalid_by_host_chart_data
          @failures_daily_chart_data
          @search_queries_daily_chart_data
          @user_confirmation_rate_chart_data
          @user_registration_sources_chart_data
          @user_cumulative_growth_chart_data
        ]
      }.freeze

      before_action :authorize_metrics_access
      before_action :set_min_dates, only: :index
      before_action :set_initial_metrics_data, only: :index

      # Main dashboard view - loads initial state with default date range
      def index; end

      # JSON endpoint for page views grouped by URL and pageable_type (stacked bar chart)
      def page_views_by_url_data # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        render json: page_views_by_url_payload(filtered_metrics_scope(BetterTogether::Metrics::PageView, :viewed_at))
      end

      # JSON endpoint for daily page views grouped by pageable_type (stacked line chart)
      def page_views_daily_data # rubocop:disable Metrics/AbcSize
        render json: page_views_daily_payload(filtered_metrics_scope(BetterTogether::Metrics::PageView, :viewed_at))
      end

      # JSON endpoint for link clicks grouped by URL
      def link_clicks_by_url_data
        render json: labeled_values_payload(filtered_metrics_scope(BetterTogether::Metrics::LinkClick, :clicked_at), :url)
      end

      # JSON endpoint for daily link clicks
      def link_clicks_daily_data
        render json: daily_values_payload(filtered_metrics_scope(BetterTogether::Metrics::LinkClick, :clicked_at), :clicked_at)
      end

      # JSON endpoint for top search queries by term
      def search_queries_by_term_data
        render json: search_queries_by_term_payload(filtered_metrics_scope(BetterTogether::Metrics::SearchQuery, :searched_at))
      end

      # JSON endpoint for daily search queries
      def search_queries_daily_data
        render json: daily_values_payload(filtered_metrics_scope(BetterTogether::Metrics::SearchQuery, :searched_at), :searched_at)
      end

      # JSON endpoint for search index drift by model
      def search_health_data
        audit = BetterTogether::Search::AuditService.new.call

        render json: {
          labels: audit.entries.map { |entry| entry.model_name.demodulize },
          values: audit.entries.map(&:drift_count),
          backend: audit.backend,
          status: audit.status,
          report_labels: audit.report_labels,
          capabilities: audit.capabilities
        }
      end

      def search_health_panel
        @search_health_report = BetterTogether::Search::AuditService.new.call
        render partial: 'better_together/metrics/reports/search_health_contents'
      end

      # JSON endpoint for daily user account creation and confirmation
      def user_accounts_daily_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        render json: user_accounts_daily_payload(filter_by_datetime(BetterTogether::User, :created_at))
      end

      # JSON endpoint for confirmation rate trend
      def user_confirmation_rate_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        render json: user_confirmation_rate_payload(filter_by_datetime(BetterTogether::User, :created_at))
      end

      # JSON endpoint for registration sources breakdown
      def user_registration_sources_data # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        render json: user_registration_sources_payload(filter_by_datetime(BetterTogether::User, :created_at))
      end

      # JSON endpoint for cumulative user growth
      def user_cumulative_growth_data # rubocop:disable Metrics/AbcSize
        render json: user_cumulative_growth_payload(filter_by_datetime(BetterTogether::User, :created_at))
      end

      # JSON endpoint for downloads grouped by file name
      def downloads_by_file_data
        render json: labeled_values_payload(filtered_metrics_scope(BetterTogether::Metrics::Download, :downloaded_at), :file_name, limit: nil)
      end

      # JSON endpoint for shares grouped by platform
      def shares_by_platform_data
        render json: shares_by_platform_payload(filtered_metrics_scope(BetterTogether::Metrics::Share, :shared_at))
      end

      # JSON endpoint for shares grouped by URL and platform (stacked bar chart)
      def shares_by_url_and_platform_data # rubocop:todo Metrics/AbcSize
        render json: shares_by_url_and_platform_payload(filtered_metrics_scope(BetterTogether::Metrics::Share, :shared_at))
      end

      # JSON endpoint for links grouped by host
      def links_by_host_data
        render json: labeled_values_payload(link_checker_scope(:created_at), :host, limit: nil)
      end

      # JSON endpoint for invalid links grouped by host
      def invalid_by_host_data
        render json: labeled_values_payload(link_checker_scope(:created_at, valid_only: false), :host, limit: nil)
      end

      # JSON endpoint for daily invalid links
      def failures_daily_data
        render json: daily_values_payload(link_checker_scope(:last_checked_at, valid_only: false), :last_checked_at)
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
          page_views: (metrics_scope(BetterTogether::Metrics::PageView).minimum(:viewed_at) || 1.year.ago) - 1.day,
          link_clicks: (metrics_scope(BetterTogether::Metrics::LinkClick).minimum(:clicked_at) || 1.year.ago) - 1.day,
          downloads: (metrics_scope(BetterTogether::Metrics::Download).minimum(:downloaded_at) || 1.year.ago) - 1.day,
          shares: (metrics_scope(BetterTogether::Metrics::Share).minimum(:shared_at) || 1.year.ago) - 1.day,
          link_checker: (BetterTogether::Content::Link.minimum(:created_at) || 1.year.ago) - 1.day,
          search_queries: (metrics_scope(BetterTogether::Metrics::SearchQuery).minimum(:searched_at) || 1.year.ago) - 1.day,
          user_accounts: (BetterTogether::User.minimum(:created_at) || 1.year.ago) - 1.day
        }
      end
      # rubocop:enable Metrics/AbcSize

      def set_initial_metrics_data
        initialize_default_datetime_range
        assign_empty_metric_payloads
        @result_levels = BetterTogether::Metrics::DEFAULT_RESULT_LEVELS
      end

      # Calculate average results for search queries
      def calculate_average_results(scope, queries)
        scope.where(query: queries)
             .group(:query)
             .average(:results_count)
             .transform_values { |v| v.to_f.round(1) }
      end

      def initialize_default_datetime_range
        @start_date ||= 30.days.ago.beginning_of_day
        @end_date ||= Time.current.end_of_day
        @locale_filter = nil
        @pageable_type_filter = nil
        @hour_of_day_filter = nil
        @day_of_week_filter = nil
      end

      def assign_empty_metric_payloads
        EMPTY_REPORT_PAYLOADS.each do |payload_method, instance_variables|
          assign_payloads(public_send(payload_method), *instance_variables)
        end
        @search_queries_by_term_chart_data = empty_search_query_payload
      end

      def assign_payloads(payload, *instance_variables)
        instance_variables.each { |name| instance_variable_set(name, payload.deep_dup) }
      end

      def filtered_metrics_scope(model, column_name)
        filter_by_datetime(metrics_scope(model), column_name)
      end

      def empty_stacked_payload
        { labels: [], datasets: [] }
      end

      def empty_values_payload
        { labels: [], values: [] }
      end

      def empty_search_query_payload
        empty_values_payload.merge(avgResults: [], thresholds: BetterTogether::Metrics.generate_result_levels([]))
      end

      def link_checker_scope(column_name, valid_only: nil)
        scope = BetterTogether::Content::Link.all
        scope = scope.where(valid_link: valid_only) unless valid_only.nil?
        scope.where(column_name => @start_date..@end_date)
      end

      def page_views_by_url_payload(scope)
        grouped_counts = scope.group(:page_url, :pageable_type).count
        pageable_types = grouped_counts.keys.map(&:last).uniq
        urls = top_labels(grouped_counts).take(20)

        {
          labels: urls,
          datasets: pageable_types.map do |pageable_type|
            {
              label: localized_model_name(pageable_type),
              backgroundColor: viewable_type_color(pageable_type),
              data: urls.map { |url| grouped_counts.fetch([url, pageable_type], 0) }
            }
          end
        }
      end

      def page_views_daily_payload(scope)
        grouped_counts = scope.group_by_day(:viewed_at).group(:pageable_type).count
        pageable_types = grouped_counts.keys.map(&:last).uniq
        days = grouped_counts.keys.map(&:first).uniq.sort

        {
          labels: days.map(&:to_s),
          datasets: page_view_daily_datasets(pageable_types, days, grouped_counts)
        }
      end

      def labeled_values_payload(scope, column_name, limit: 20)
        grouped_counts = scope.group(column_name).count
        labels = limit.nil? ? grouped_counts.keys : top_labels(grouped_counts).take(limit)

        {
          labels: labels,
          values: labels.map { |label| grouped_counts[label] || 0 }
        }
      end

      def daily_values_payload(scope, column_name)
        grouped_counts = scope.group_by_day(column_name).count

        {
          labels: grouped_counts.keys.map(&:to_s),
          values: grouped_counts.values
        }
      end

      def search_queries_by_term_payload(scope)
        search_counts = labeled_values_payload(scope, :query)
        avg_results = calculate_average_results(scope, search_counts[:labels])
        avg_results_array = search_counts[:labels].map { |query| avg_results[query] || 0 }

        search_counts.merge(
          avgResults: avg_results_array,
          thresholds: BetterTogether::Metrics.generate_result_levels(avg_results_array)
        )
      end

      def user_accounts_daily_payload(users_scope)
        created_by_day = users_scope.group_by_day(:created_at).count
        confirmed_by_day = users_scope.where.not(confirmed_at: nil).group_by_day(:confirmed_at).count

        {
          labels: date_range_labels,
          datasets: [
            user_accounts_dataset('accounts_created', 'rgba(54, 162, 235, 0.2)', 'rgba(54, 162, 235, 1)', created_by_day),
            user_accounts_dataset('accounts_confirmed', 'rgba(75, 192, 192, 0.2)', 'rgba(75, 192, 192, 1)', confirmed_by_day)
          ]
        }
      end

      def user_confirmation_rate_payload(users_scope)
        created_by_day = users_scope.group_by_day(:created_at).count
        confirmed_by_day = users_scope.where.not(confirmed_at: nil).group_by_day(:confirmed_at).count

        {
          labels: date_range_labels,
          values: date_range_days.map do |day|
            created_count = created_by_day.fetch(day, 0)
            next 0 if created_count.zero?

            ((confirmed_by_day.fetch(day, 0).to_f / created_count) * 100).round(2)
          end
        }
      end

      def user_registration_sources_payload(users_scope)
        all_user_ids = users_scope.ids
        invitation_user_ids = invitation_user_ids_for(all_user_ids)
        oauth_user_ids = oauth_user_ids_for(all_user_ids)
        special_user_ids = (invitation_user_ids + oauth_user_ids).uniq

        {
          labels: user_registration_source_labels,
          values: [
            (all_user_ids - special_user_ids).count,
            invitation_user_ids.length,
            oauth_user_ids.length
          ]
        }
      end

      def user_cumulative_growth_payload(users_scope)
        created_by_day = users_scope.group_by_day(:created_at).count
        cumulative_total = 0

        {
          labels: date_range_labels,
          values: date_range_days.map do |day|
            cumulative_total += created_by_day.fetch(day, 0)
            cumulative_total
          end
        }
      end

      def shares_by_platform_payload(scope)
        data = scope.group(:platform).count

        {
          labels: data.keys,
          datasets: [{
            label: 'Shares by Platform',
            data: data.values,
            backgroundColor: data.keys.map { |platform| platform_color(platform) },
            borderColor: data.keys.map { |platform| platform_color(platform, border: true) },
            borderWidth: 1
          }]
        }
      end

      def shares_by_url_and_platform_payload(scope)
        grouped_counts = scope.group(:url, :platform).count
        platforms = grouped_counts.keys.map(&:last).uniq
        urls = grouped_counts.keys.map(&:first).uniq

        {
          labels: urls,
          datasets: platforms.map do |platform|
            {
              label: platform.capitalize,
              backgroundColor: platform_color(platform),
              data: urls.map { |url| grouped_counts.fetch([url, platform], 0) }
            }
          end
        }
      end

      def top_labels(grouped_counts)
        totals = grouped_counts.each_with_object(Hash.new(0)) do |(key, count), memo|
          label = key.is_a?(Array) ? key.first : key
          memo[label] += count
        end

        totals.sort_by { |_label, count| -count }.map(&:first)
      end

      def date_range_days
        (@start_date.to_date..@end_date.to_date).to_a
      end

      def date_range_labels
        date_range_days.map(&:to_s)
      end

      def invitation_user_ids_for(user_ids) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        return [] if user_ids.empty?

        identifications = BetterTogether::Identification.arel_table
        invitations = BetterTogether::Invitation.arel_table

        scoped_user_identifications(user_ids)
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
      end

      def oauth_user_ids_for(user_ids)
        return [] if user_ids.empty?

        identifications = BetterTogether::Identification.arel_table
        platform_integrations = BetterTogether::PersonPlatformIntegration.arel_table

        scoped_user_identifications(user_ids)
          .joins(
            Arel::Nodes::InnerJoin.new(
              platform_integrations,
              Arel::Nodes::On.new(platform_integrations[:person_id].eq(identifications[:identity_id]))
            )
          )
          .pluck(:agent_id)
          .uniq
      end

      def page_view_daily_datasets(pageable_types, days, grouped_counts)
        pageable_types.map do |pageable_type|
          {
            label: localized_model_name(pageable_type),
            backgroundColor: viewable_type_color(pageable_type),
            borderColor: viewable_type_color(pageable_type, border: true),
            data: days.map { |day| grouped_counts.fetch([day, pageable_type], 0) },
            fill: true
          }
        end
      end

      def user_accounts_dataset(label_key, background_color, border_color, grouped_counts)
        {
          label: I18n.t("better_together.metrics.reports.charts.#{label_key}", default: label_key.humanize),
          backgroundColor: background_color,
          borderColor: border_color,
          data: date_range_days.map { |day| grouped_counts.fetch(day, 0) },
          fill: true
        }
      end

      def user_registration_source_labels
        [
          I18n.t('better_together.metrics.reports.charts.open_registration', default: 'Open Registration'),
          I18n.t('better_together.metrics.reports.charts.invitation', default: 'Invitation'),
          I18n.t('better_together.metrics.reports.charts.oauth', default: 'OAuth/Social')
        ]
      end

      def scoped_user_identifications(user_ids)
        BetterTogether::Identification.where(
          active: true,
          agent_type: 'BetterTogether::User',
          agent_id: user_ids,
          identity_type: 'BetterTogether::Person'
        )
      end

      def metrics_scope(model)
        model.for_platform(metrics_platform)
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
