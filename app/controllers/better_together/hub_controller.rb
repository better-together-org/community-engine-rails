# frozen_string_literal: true

module BetterTogether
  # Internal hub for logged-in users to see relevant platform & community information
  class HubController < ApplicationController
    def index
      authorize PublicActivity::Activity
      @activities = helpers.activities

      # Recent Joatu offers and requests (policy scoped)
      @recent_offers = policy_scope(BetterTogether::Joatu::Offer)
                        .order(created_at: :desc)
                        .limit(5)
      @recent_requests = policy_scope(BetterTogether::Joatu::Request)
                          .order(created_at: :desc)
                          .limit(5)
    end
  end
end
