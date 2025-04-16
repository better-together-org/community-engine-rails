# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    def search
      searchable_models = BetterTogether::Searchable.included_in_models
      @query = params[:q]
      search_results = []
      suggestions = []

      if @query.present?
        response = Elasticsearch::Model.search({
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: @query,
                    fields: ['title^3', 'content', 'blocks.rich_text_content.body^2', 'formatted_address^2', 'name^3', 'description^2'],
                    type: 'best_fields'
                  }
                }
              ]
            }
          },
          suggest: {
            text: @query,
            suggestions: {
              term: {
                field: 'name',
                suggest_mode: 'always'
              }
            }
          }
        }, searchable_models)

        search_results = response.records.to_a
        suggestions = response.response['suggest']['suggestions'].map { |s| s['options'].map { |o| o['text'] } }.flatten
      end

      # Use Kaminari for pagination
      @results = Kaminari.paginate_array(search_results).page(params[:page]).per(10)
      @suggestions = suggestions
    end

  end
end
