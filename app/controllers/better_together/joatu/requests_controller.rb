module BetterTogether
  module Joatu
    # RequestsController handles Joatu request operations
    class RequestsController < ApplicationController
      # GET /joatu/requests/:id/matches
      def matches
        @request = BetterTogether::Joatu::Request.find(params[:id])
        @matches = BetterTogether::Joatu::Matchmaker.match(@request)
      end
    end
  end
end
