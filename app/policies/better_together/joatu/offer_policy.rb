# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Offer
    class OfferPolicy < ApplicationPolicy
      def index? = user.present?
      def show?  = user.present?
      def create? = user.present?
      alias new? create?

      def update?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end
      alias edit? update?

      def destroy?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          # For now, allow authenticated users to see all offers.
          return scope.none unless user.present?

          # Platform managers see everything
          return scope.all if permitted_to?('manage_platform')

          agent_id = agent&.id

          # Offers that are not responses to another resource (no response_link where response is this offer)
          not_responses = scope.left_joins(:response_links_as_response).where(better_together_joatu_response_links: { id: nil })

          # Offers owned by the agent
          owned = scope.where(creator_id: agent_id)

          # Offers that are responses to a Request where that Request's creator is the agent
          # We join response links to the requests table via explicit SQL because the association is polymorphic
          response_to_my_request = scope.joins("JOIN better_together_joatu_response_links rl ON rl.response_type = 'BetterTogether::Joatu::Offer' AND rl.response_id = better_together_joatu_offers.id JOIN better_together_joatu_requests r ON rl.source_type = 'BetterTogether::Joatu::Request' AND rl.source_id = r.id").where('r.creator_id = ?', agent_id)

          # Combine the allowed sets: not_responses (public) OR owned OR response_to_my_request
          scope.where(id: not_responses.select(:id)).or(scope.where(id: owned.select(:id))).or(scope.where(id: response_to_my_request.select(:id)))
        end
      end
    end
  end
end
