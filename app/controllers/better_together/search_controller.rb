 module BetterTogether
  class SearchController < ApplicationController
    def search
      @query = params[:q]
      if @query.present?
        @results = BetterTogether::Page.search(@query).records
      else
        @results = []
      end
    end
  end
 end