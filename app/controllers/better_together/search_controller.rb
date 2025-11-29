# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    def search # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      searchable_models = BetterTogether::Searchable.included_in_models
      @query = params[:q]
      search_results = []
      suggestions = []

      if @query.present?
        begin
          response = Elasticsearch::Model.search(build_search_query(@query), searchable_models)

          search_results = response.records.to_a

          suggest_source = response.response.dig('suggest', 'suggestions') || []
          suggestions = suggest_source.flat_map { |s| s.fetch('options', []).map { |o| o['text'] } }

          BetterTogether::Metrics::TrackSearchQueryJob.perform_later(
            @query,
            search_results.length,
            I18n.locale.to_s
          )
        rescue StandardError => e
          Rails.logger.warn("Search error: #{e.class}: #{e.message}")
          # Fall back to empty results so the page still renders
          search_results = []
          suggestions = []
        end
      end

      # Use Kaminari for pagination
      @results = Kaminari.paginate_array(search_results).page(params[:page]).per(10)
      @suggestions = suggestions
    end

    private

    def build_search_query(query) # rubocop:todo Metrics/MethodLength
      {
        query: {
          bool: {
            must: [
              {
                multi_match: {
                  query: query,
                  type: 'best_fields'
                }
              }
            ]
          }
        },
        suggest: {
          text: query,
          suggestions: {
            term: {
              field: 'name',
              suggest_mode: 'always'
            }
          }
        }
      }
    end
  end
end
