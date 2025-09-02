# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Offer
    class OfferPolicy < ApplicationPolicy
      def index? = user.present?
      def show?  = user.present?
      def create? = user.present?
      alias new? create?

      # Permission helper for the "respond with request" flow (creating an Offer from a Request)
      def respond_with_request? = create?

      def update?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end
      alias edit? update?

      def destroy?
        return false unless user.present?

        # Prevent destroy if there are any agreements for this offer — applies to everyone
        return false if record.respond_to?(:agreements) && record.agreements.exists?

        # Platform managers or the creator may destroy when there are no agreements
        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        # rubocop:todo Metrics/MethodLength
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          # For now, allow authenticated users to see all offers.
          return scope.none unless user.present?

          # Platform managers see everything
          return scope.all if permitted_to?('manage_platform')

          agent_id = agent&.id

          # Offers that are not responses to another resource (no response_link where response is this offer)
          # rubocop:todo Layout/LineLength
          not_responses = scope.left_joins(:response_links_as_response).where(better_together_joatu_response_links: { id: nil })
          # rubocop:enable Layout/LineLength

          # Offers owned by the agent
          owned = scope.where(creator_id: agent_id)

          # Offers that are responses to a Request where that Request's creator is the agent
          rl = BetterTogether::Joatu::ResponseLink.arel_table
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          # rubocop:todo Layout/LineLength
          # build: JOIN response_links rl ON rl.response_type = 'BetterTogether::Joatu::Offer' AND rl.response_id = offers.id
          # rubocop:enable Layout/LineLength
          #        JOIN requests r ON rl.source_type = 'BetterTogether::Joatu::Request' AND rl.source_id = requests.id
          join_on_rl = rl[:response_type].eq(BetterTogether::Joatu::Offer.name).and(rl[:response_id].eq(offers[:id]))
          join_on_requests = rl[:source_type].eq(BetterTogether::Joatu::Request.name).and(rl[:source_id].eq(requests[:id]))

          join_sources = offers.join(rl, Arel::Nodes::InnerJoin).on(join_on_rl).join(requests, Arel::Nodes::InnerJoin).on(join_on_requests).join_sources

          response_to_my_request = scope.joins(join_sources).where(requests[:creator_id].eq(agent_id))

          # Combine the allowed sets: not_responses (public) OR owned OR response_to_my_request
          # rubocop:todo Layout/LineLength
          scope.where(id: not_responses.select(:id)).or(scope.where(id: owned.select(:id))).or(scope.where(id: response_to_my_request.select(:id)))
          # rubocop:enable Layout/LineLength
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
