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
        ]
      end

      private

      # Set the datetime range for filtering metrics
      # Defaults to last 30 days if not specified
      # Validates that start_date is before end_date
      # Limits maximum range to 1 year
      def set_datetime_range
        @start_date = parse_date_param(params[:start_date]) || 30.days.ago.beginning_of_day
        @end_date = parse_date_param(params[:end_date]) || Time.current.end_of_day

        validate_datetime_range!
      end

      # Parse date parameter from ISO 8601 format
      def parse_date_param(date_string)
        return nil if date_string.blank?

        Time.zone.parse(date_string)
      rescue ArgumentError
        nil
      end

      # Validate datetime range constraints
      def validate_datetime_range!
        if @start_date > @end_date
          render json: { error: I18n.t('better_together.metrics.errors.invalid_date_range') },
                 status: :unprocessable_entity
          return
        end

        max_range = 1.year
        return unless @end_date - @start_date > max_range

        render json: { error: I18n.t('better_together.metrics.errors.date_range_too_large') },
               status: :unprocessable_entity
      end

      # Apply datetime filter to a scope based on a timestamp column
      def filter_by_datetime(scope, column_name)
        scope.where(column_name => @start_date..@end_date)
      end
    end
  end
end
