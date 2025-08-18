# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Request
    class RequestsController < JoatuController
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def index # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        @joatu_requests = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).includes(:categories, :creator)

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call

        # Aggregate potential matches for all of the current user's requests (policy-scoped),
        # with sensible limits to avoid heavy queries.
        if helpers.current_person
          max_requests = (ENV['JOATU_AGG_MATCH_MAX_REQUESTS'] || 25).to_i
          max_per_request = (ENV['JOATU_AGG_MATCH_PER_REQUEST'] || 10).to_i
          max_total_matches = (ENV['JOATU_AGG_MATCH_TOTAL'] || 50).to_i

          my_requests_scope = policy_scope(BetterTogether::Joatu::Request)
                              .where(creator_id: helpers.current_person.id)
                              .order(created_at: :desc)
                              .limit(max_requests)

          offer_request_map = {}
          offer_ids = []

          my_requests_scope.find_each(batch_size: 10) do |request|
            break if offer_ids.size >= max_total_matches

            BetterTogether::Joatu::Matchmaker
              .match(request)
              .limit([max_per_request, (max_total_matches - offer_ids.size)].min)
              .each do |offer|
                next if offer_request_map.key?(offer.id)

                offer_request_map[offer.id] = request
                offer_ids << offer.id
              end
          end

          @request_match_offer_map = offer_request_map
          @aggregated_offer_matches = if offer_ids.any?
                                        BetterTogether::Joatu::Offer.where(id: offer_ids.uniq)
                                      else
                                        BetterTogether::Joatu::Offer.none
                                      end
        else
          @request_match_offer_map = {}
          @aggregated_offer_matches = BetterTogether::Joatu::Offer.none
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # GET /joatu/requests/:id/matches
      def matches
        @joatu_request = set_resource_instance
        authorize_resource
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
