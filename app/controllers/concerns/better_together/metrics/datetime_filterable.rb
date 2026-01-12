# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Concern for handling datetime filtering in metrics controllers
    module DatetimeFilterable
      extend ActiveSupport::Concern

      included do
        before_action :set_datetime_range, only: %i[
          page_views_by_url_data
          page_views_daily_data
          link_clicks_by_url_data
          link_clicks_daily_data
          downloads_by_file_data
          shares_by_platform_data
          shares_by_url_and_platform_data
          links_by_host_data
          invalid_by_host_data
          failures_daily_data
          search_queries_by_term_data
          search_queries_daily_data
          user_accounts_daily_data
          user_confirmation_rate_data
          user_registration_sources_data
          user_cumulative_growth_data
        ]
      end

      private

      # Set the datetime range for filtering metrics
      # Defaults to last 30 days if not specified
      # Validates constraints and halts execution with error if invalid
      # rubocop:disable Metrics/AbcSize
      def set_datetime_range
        @start_date = parse_date_param(params[:start_date]) || 30.days.ago.beginning_of_day
        @end_date = parse_date_param(params[:end_date]) || Time.current.end_of_day
        @locale_filter = params[:filter_locale].presence
        @pageable_type_filter = params[:pageable_type].presence
        @hour_of_day_filter = params[:hour_of_day].presence&.to_i
        @day_of_week_filter = params[:day_of_week].presence&.to_i

        # Validate and halt if invalid (returns false to stop filter chain)
        validate_datetime_range!
      end
      # rubocop:enable Metrics/AbcSize

      # Parse date parameter from ISO 8601 format
      def parse_date_param(date_string)
        return nil if date_string.blank?

        Time.zone.parse(date_string)
      rescue ArgumentError
        nil
      end

      # Validate datetime range constraints
      # Returns false to halt filter chain if validation fails
      def validate_datetime_range! # rubocop:disable Naming/PredicateMethod
        if @start_date > @end_date
          render json: { error: I18n.t('better_together.metrics.errors.invalid_date_range') },
                 status: :unprocessable_content
          return false
        end

        if @end_date - @start_date > 1.year
          render json: { error: I18n.t('better_together.metrics.errors.date_range_too_large') },
                 status: :unprocessable_content
          return false
        end

        true
      end

      # Apply datetime filter to a scope based on a timestamp column
      def filter_by_datetime(scope, column_name)
        scope = scope.where(column_name => @start_date..@end_date)
        apply_additional_filters(scope, column_name)
      end

      # Apply additional filters (locale, pageable_type, hour, day of week)
      # Uses Arel for safe query construction
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def apply_additional_filters(scope, timestamp_column)
        scope = scope.where(locale: @locale_filter) if @locale_filter.present?
        scope = scope.where(pageable_type: @pageable_type_filter) if @pageable_type_filter.present?

        # Use Arel for PostgreSQL EXTRACT functions
        table = scope.arel_table

        if @hour_of_day_filter.present?
          hour_extract = Arel::Nodes::NamedFunction.new(
            'EXTRACT',
            [Arel::Nodes::SqlLiteral.new("HOUR FROM #{table.name}.#{timestamp_column}")]
          )
          scope = scope.where(hour_extract.eq(@hour_of_day_filter))
        end

        if @day_of_week_filter.present?
          dow_extract = Arel::Nodes::NamedFunction.new(
            'EXTRACT',
            [Arel::Nodes::SqlLiteral.new("DOW FROM #{table.name}.#{timestamp_column}")]
          )
          scope = scope.where(dow_extract.eq(@day_of_week_filter))
        end

        scope
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
