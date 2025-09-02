# frozen_string_literal: true

module BetterTogether
  module Metrics
    class SearchQueriesController < ApplicationController # rubocop:todo Style/Documentation
      def create
        query = params[:query]
        results_count = params[:results_count]
        locale = I18n.locale.to_s

        if query.blank? || results_count.blank?
          render json: { error: I18n.t('metrics.search_queries.invalid_parameters') },
                 status: :unprocessable_content and return
        end

        BetterTogether::Metrics::TrackSearchQueryJob.perform_later(query, results_count.to_i, locale)

        render json: { success: true }, status: :ok
      end
    end
  end
end
