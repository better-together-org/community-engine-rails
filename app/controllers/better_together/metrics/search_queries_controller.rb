# frozen_string_literal: true

module BetterTogether
  module Metrics
    class SearchQueriesController < ApplicationController # rubocop:todo Style/Documentation
      include PlatformContext

      def create # rubocop:todo Metrics/MethodLength
        query = params[:query]
        results_count = params[:results_count]
        locale = I18n.locale.to_s

        if query.blank? || results_count.blank?
          render json: { error: I18n.t('metrics.search_queries.invalid_parameters') },
                 status: :unprocessable_content and return
        end

        tracked_query = BetterTogether::Metrics::SearchQueryCaptureService.new.call(query)
        if tracked_query.present?
          BetterTogether::Metrics::TrackSearchQueryJob.perform_later(
            tracked_query,
            results_count.to_i,
            locale,
            metrics_platform.id,
            metrics_logged_in?
          )
        end

        render json: { success: true }, status: :ok
      end
    end
  end
end
