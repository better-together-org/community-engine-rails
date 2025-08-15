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
        @requests = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        )

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call
      end

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
        :request
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
          provided = Array(attrs[:category_ids]).reject(&:blank?)
          if provided.empty? && BetterTogether::Joatu::Category.exists?
            attrs[:category_ids] = [BetterTogether::Joatu::Category.first.id]
          end
        end
      end
    end
  end
end
