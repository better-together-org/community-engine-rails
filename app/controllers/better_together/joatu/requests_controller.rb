# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < FriendlyResourceController
      # GET /joatu/requests/:id/matches
      def matches
        @request = BetterTogether::Joatu::Request.find(params[:id])
        @matches = BetterTogether::Joatu::Matchmaker.match(@request)
      end

      protected

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def param_name
        :"joatu_#{super}"
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
        end
      end
    end
  end
end
