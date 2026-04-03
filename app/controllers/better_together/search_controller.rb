# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    include Metrics::PlatformContext

    def search # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
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
      query = BetterTogether::Metrics::SearchQueryCaptureService.new.call(@query)
      return if query.blank?

      BetterTogether::Metrics::TrackSearchQueryJob.perform_later(
        query,
        search_results.records.length,
        I18n.locale.to_s,
        metrics_platform.id,
        metrics_logged_in?
      )
    end

    def assign_search_results(search_results)
      @results = Kaminari.paginate_array(visible_search_records(search_results.records)).page(params[:page]).per(10)
      # Backend term suggestions are not privacy-aware and can leak unpublished or
      # private titles. Keep them disabled until the search backend can scope them.
      @suggestions = []
      @search_backend = search_results.backend
      @search_status = search_results.status
    end

    def log_search_error(search_results)
      return unless search_results.status == :unreachable

      Rails.logger.warn("Search error: #{search_results.error}")
    end

    def visible_search_records(records)
      Array(records).select { |record| search_record_visible?(record) }
    end

    def search_record_visible?(record)
      return public_search_record?(record) if current_user.nil?

      policy(record).show?
    rescue Pundit::Error, NoMethodError
      false
    end

    def public_search_record?(record)
      privacy_visible = !record.respond_to?(:privacy_public?) || record.privacy_public?
      publish_visible = !record.respond_to?(:published?) || record.published?

      privacy_visible && publish_visible
    end
  end
end
