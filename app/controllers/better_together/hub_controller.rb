# frozen_string_literal: true

module BetterTogether
  # Internal hub for logged-in users to see relevant platform & community information
  class HubController < ApplicationController
    def index
      authorize PublicActivity::Activity
      @activities = helpers.activities.order(created_at: :desc).limit(5)

      # Recent Joatu offers and requests (policy scoped)
      @recent_offers = policy_scope(BetterTogether::Joatu::Offer)
                       .includes(:creator, :categories)
                       .order(created_at: :desc)
                       .limit(5)
      @recent_requests = policy_scope(BetterTogether::Joatu::Request)
                         .includes(:creator, :categories)
                         .order(created_at: :desc)
                         .limit(5)
    end

    def activities
      authorize PublicActivity::Activity, :index?
      @activities = helpers.activities.order(created_at: :desc)
    end
  end
end
