# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Request
    class RequestPolicy < ApplicationPolicy
      def index? = user.present?
      def show?  = user.present?
      def create? = user.present?
      alias new? create?

      def update?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end
      alias edit? update?
      alias matches? update?

      def destroy?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.none unless user.present?

          # Platform managers see everything
          return scope.all if permitted_to?('manage_platform')

          agent_id = agent&.id

          # Requests that are not responses to another resource (no response_link where response is this request)
          not_responses = scope.left_joins(:response_links_as_response).where(better_together_joatu_response_links: { id: nil })

          # Requests owned by the agent
          owned = scope.where(creator_id: agent_id)

          # Requests that are responses to an Offer owned by the agent
          response_to_my_offer = scope.joins("JOIN better_together_joatu_response_links rl ON rl.response_type = 'BetterTogether::Joatu::Request' AND rl.response_id = better_together_joatu_requests.id JOIN better_together_joatu_offers o ON rl.source_type = 'BetterTogether::Joatu::Offer' AND rl.source_id = o.id").where('o.creator_id = ?', agent_id)

          scope.where(id: not_responses.select(:id)).or(scope.where(id: owned.select(:id))).or(scope.where(id: response_to_my_offer.select(:id)))
        end
      end
    end
  end
end
