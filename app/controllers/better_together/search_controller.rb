# frozen_string_literal: true

module BetterTogether
  # Handles dispatching search queries to elasticsearch and displaying the results
  class SearchController < ApplicationController
    def search
      @query = params[:q]
      @results = if @query.present?
                   BetterTogether::Page.search(@query).records
                 else
                   []
                 end
    end
  end
end
