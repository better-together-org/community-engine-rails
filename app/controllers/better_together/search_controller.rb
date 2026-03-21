# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    def search
      @query = params[:q]
      search_results = perform_search

      track_search_query(search_results) if @query.present?
      assign_search_results(search_results)
    end

    private

    def perform_search
      return idle_search_result unless @query.present?

      search_results = BetterTogether::Search.backend.search(@query)
      log_search_error(search_results)
      search_results
    end

    def idle_search_result
      BetterTogether::Search::SearchResult.new(
        records: [],
        suggestions: [],
        status: :idle,
        backend: BetterTogether::Search.backend.backend_key
      )
    end

    def track_search_query(search_results)
      BetterTogether::Metrics::TrackSearchQueryJob.perform_later(
        @query,
        search_results.records.length,
        I18n.locale.to_s
      )
    end

    def assign_search_results(search_results)
      @results = Kaminari.paginate_array(search_results.records).page(params[:page]).per(10)
      @suggestions = search_results.suggestions
      @search_backend = search_results.backend
      @search_status = search_results.status
    end

    def log_search_error(search_results)
      return unless search_results.status == :unreachable

      Rails.logger.warn("Search error: #{search_results.error}")
    end
  end
end
