# frozen_string_literal: true

module BetterTogether
  # Internal hub for logged-in users to see relevant platform & community information
  class HubController < ApplicationController
    def index
      authorize PublicActivity::Activity
      @activities = helpers.activities

      # Recent Joatu offers and requests (policy scoped)
      @recent_offers = policy_scope(BetterTogether::Joatu::Offer)
                        .includes(:creator, :categories)
                        .order(created_at: :desc)
                        .limit(5)
      @recent_requests = policy_scope(BetterTogether::Joatu::Request)
                          .includes(:creator, :categories)
                          .order(created_at: :desc)
                          .limit(5)

      # Suggested matches context (personalized, no cache)
      @latest_offer = policy_scope(BetterTogether::Joatu::Offer)
                       .where(creator_id: helpers.current_person&.id)
                       .order(created_at: :desc)
                       .first
      @latest_request = policy_scope(BetterTogether::Joatu::Request)
                         .where(creator_id: helpers.current_person&.id)
                         .order(created_at: :desc)
                         .first
    end

    def recent_offers
      @recent_offers = policy_scope(BetterTogether::Joatu::Offer)
                        .includes(:creator, :categories)
                        .order(created_at: :desc)
                        .limit(5)
      render partial: 'better_together/hub/recent_offers_frame', locals: { offers: @recent_offers }
    end

    def recent_requests
      @recent_requests = policy_scope(BetterTogether::Joatu::Request)
                          .includes(:creator, :categories)
                          .order(created_at: :desc)
                          .limit(5)
      render partial: 'better_together/hub/recent_requests_frame', locals: { requests: @recent_requests }
    end

    def suggested_matches
      @latest_offer = policy_scope(BetterTogether::Joatu::Offer)
                       .where(creator_id: helpers.current_person&.id)
                       .order(created_at: :desc).first
      @latest_request = policy_scope(BetterTogether::Joatu::Request)
                         .where(creator_id: helpers.current_person&.id)
                         .order(created_at: :desc).first
      render partial: 'better_together/hub/suggested_matches_frame',
             locals: { latest_offer: @latest_offer, latest_request: @latest_request }
    end
  end
end
