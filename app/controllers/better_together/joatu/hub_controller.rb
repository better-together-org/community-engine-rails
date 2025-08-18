# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Landing page for the Exchange hub
    class HubController < BetterTogether::ApplicationController
      def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        person = helpers.current_person

        # Personalized sections
        @my_offers = person ? BetterTogether::Joatu::Offer.where(creator_id: person.id).order(updated_at: :desc).limit(10) : BetterTogether::Joatu::Offer.none
        @my_requests = person ? BetterTogether::Joatu::Request.where(creator_id: person.id).order(updated_at: :desc).limit(10) : BetterTogether::Joatu::Request.none

        # Agreements where current person is creator of either side
        if person
          @my_agreements = BetterTogether::Joatu::Agreement
                           .includes(:offer, :request)
                           .where(offer_id: @my_offers.select(:id))
                           .or(BetterTogether::Joatu::Agreement.where(request_id: @my_requests.select(:id)))
                           .order(updated_at: :desc)
                           .limit(10)
        else
          @my_agreements = BetterTogether::Joatu::Agreement.none
        end

        # Recent activity from others
        @recent_offers = BetterTogether::Joatu::Offer.order(created_at: :desc)
                                .where.not(creator_id: person&.id)
                                .limit(10)
        @recent_requests = BetterTogether::Joatu::Request.order(created_at: :desc)
                                  .where.not(creator_id: person&.id)
                                  .limit(10)

        # Lightweight suggestions (limit queries)
        @suggested_request_matches = []
        @suggested_offer_matches = []
        if person
          @my_offers.limit(5).each do |offer|
            BetterTogether::Joatu::Matchmaker.match(offer).limit(3).each do |req|
              @suggested_request_matches << [offer, req]
            end
          end

          @my_requests.limit(5).each do |req|
            BetterTogether::Joatu::Matchmaker.match(req).limit(3).each do |offer|
              @suggested_offer_matches << [req, offer]
            end
          end
        end
      end
    end
  end
end
