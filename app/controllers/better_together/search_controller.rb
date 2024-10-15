# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    def search
      @query = params[:q]

      if @query.present?
        search_response = BetterTogether::Page.search({
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: @query,
                    fields: ['title^2', 'content', 'blocks.rich_text_content.body'],
                    type: 'best_fields'
                  }
                }
              ]
            }
          },
          highlight: {
            fields: {
              title: {},
              content: {},
              'blocks.rich_text_content.body': {
                fragment_size: 150,
                number_of_fragments: 3
              }
            }
          }
        })

        # Use Kaminari for pagination
        @results = Kaminari.paginate_array(search_response.records.to_a).page(params[:page]).per(10)
        @highlights = search_response.response['hits']['hits']
      else
        @results = BetterTogether::Page.none.page(params[:page]).per(10)
        @highlights = []
      end
    end

  end
end
