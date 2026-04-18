# frozen_string_literal: true

module BetterTogether
  module Metrics
    class SearchQueriesController < ApplicationController # rubocop:todo Style/Documentation
      include PlatformContext

      def create
        return render_invalid_parameters if invalid_search_query_params?

        track_search_query if tracked_query.present?
        render json: { success: true }, status: :ok
      end

      private

      def invalid_search_query_params?
        params[:query].blank? || params[:results_count].blank?
      end

      def tracked_query
        @tracked_query ||= BetterTogether::Metrics::SearchQueryCaptureService.new.call(params[:query])
      end

      def track_search_query
        return unless metrics_platform.present?

        BetterTogether::Metrics::TrackSearchQueryJob.perform_later(
          tracked_query,
          params[:results_count].to_i,
          I18n.locale.to_s,
          metrics_platform.id,
          metrics_logged_in?
        )
      end

      def render_invalid_parameters
        render json: { error: I18n.t('metrics.search_queries.invalid_parameters') },
               status: :unprocessable_content
      end
    end
  end
end
