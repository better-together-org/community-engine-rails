# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < JoatuController
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      def index
        @joatu_requests = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).includes(:categories, :creator)

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call
      end

      # GET /joatu/requests/:id/matches
      def matches
        @joatu_request = BetterTogether::Joatu::Request.find(params[:id])
        @matches = BetterTogether::Joatu::Matchmaker.match(@joatu_request)
      end

      protected

      def resource_class
        ::BetterTogether::Joatu::Request
      end

      def resource_params
        rp = super
        rp[:creator_id] ||= helpers.current_person&.id
        rp
      end
    end
  end
end
