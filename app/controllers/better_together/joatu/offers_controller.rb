# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Offer
    class OffersController < JoatuController
      def show
        super
        mark_match_notifications_read_for(resource_instance)
      end

      def index
        @joatu_offers = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        ).includes(:categories, :creator)

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call

        # Aggregate potential matches for all of the current user's offers (policy-scoped),
        # with sensible limits to avoid heavy queries.
        if helpers.current_person
          max_offers = (ENV['JOATU_AGG_MATCH_MAX_OFFERS'] || 25).to_i
          max_per_offer = (ENV['JOATU_AGG_MATCH_PER_OFFER'] || 10).to_i
          max_total_matches = (ENV['JOATU_AGG_MATCH_TOTAL'] || 50).to_i

          my_offers_scope = policy_scope(BetterTogether::Joatu::Offer)
                            .where(creator_id: helpers.current_person.id)
                            .order(created_at: :desc)
                            .limit(max_offers)

          request_offer_map = {}
          request_ids = []

          my_offers_scope.find_each(batch_size: 10) do |offer|
            break if request_ids.size >= max_total_matches

            BetterTogether::Joatu::Matchmaker
              .match(offer)
              .limit([max_per_offer, (max_total_matches - request_ids.size)].min)
              .each do |req|
                next if request_offer_map.key?(req.id)

                request_offer_map[req.id] = offer
                request_ids << req.id
              end
          end

          @offer_match_request_map = request_offer_map
          @aggregated_request_matches = if request_ids.any?
                                          BetterTogether::Joatu::Request.where(id: request_ids.uniq)
                                        else
                                          BetterTogether::Joatu::Request.none
                                        end
        else
          @offer_match_request_map = {}
          @aggregated_request_matches = BetterTogether::Joatu::Request.none
        end
      end

      protected

      def resource_class
        ::BetterTogether::Joatu::Offer
      end

      def resource_params
        rp = super
        rp[:creator_id] ||= helpers.current_person&.id
        rp
      end
    end
  end
end
