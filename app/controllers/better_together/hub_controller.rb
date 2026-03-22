# frozen_string_literal: true

module BetterTogether
  # Internal hub for logged-in users to see relevant platform & community information
  class HubController < ApplicationController
    def index
      authorize PublicActivity::Activity
      # Activities are already eager-loaded by the policy scope (includes :trackable, :owner)
      @activities = helpers.activities.limit(5)

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
      # Activities are already eager-loaded by the policy scope (includes :trackable, :owner)
      @activities = helpers.activities
    end
  end
end
