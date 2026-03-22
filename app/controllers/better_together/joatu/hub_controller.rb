# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Landing page for the Exchange hub
    class HubController < BetterTogether::ApplicationController
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/CyclomaticComplexity
      def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        person = helpers.current_person

        # Personalized sections — use policy_scope so visibility rules are enforced.
        # RequestPolicy::Scope excludes MembershipRequests; they are surfaced separately.
        scoped_requests = policy_scope(BetterTogether::Joatu::Request)
        scoped_offers   = policy_scope(BetterTogether::Joatu::Offer)

        @my_offers    = scoped_offers.where(creator_id: person&.id).order(updated_at: :desc).limit(10)
        @my_requests  = scoped_requests.where(creator_id: person&.id).order(updated_at: :desc).limit(10)

        # Membership requests visible to this user (own submissions + manager view)
        @membership_requests = policy_scope(BetterTogether::Joatu::MembershipRequest)
                               .order(created_at: :desc)
                               .limit(10)

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

        # Recent activity from others (scoped — no unfiltered raw queries)
        @recent_offers   = scoped_offers.where.not(creator_id: person&.id).order(created_at: :desc).limit(10)
        @recent_requests = scoped_requests.where.not(creator_id: person&.id).order(created_at: :desc).limit(10)

        # Lightweight suggestions (limit queries)
        @suggested_request_matches = []
        @suggested_offer_matches = []
        return unless person

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
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
