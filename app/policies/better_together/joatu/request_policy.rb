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
        # rubocop:todo Metrics/MethodLength
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          return scope.none unless user.present?

          # Platform managers see everything
          return scope.all if permitted_to?('manage_platform')

          agent_id = agent&.id

          # rubocop:todo Layout/LineLength
          # Requests that are not responses to another resource (no response_link where response is this request)
          # rubocop:enable Layout/LineLength
          # rubocop:todo Layout/LineLength
          not_responses = scope.left_joins(:response_links_as_response).where(better_together_joatu_response_links: { id: nil })
          # rubocop:enable Layout/LineLength

          # Requests owned by the agent
          owned = scope.where(creator_id: agent_id)

          # Requests that are responses to an Offer owned by the agent
          rl = BetterTogether::Joatu::ResponseLink.arel_table
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          # rubocop:todo Layout/LineLength
          # build: JOIN response_links rl ON rl.response_type = 'BetterTogether::Joatu::Request' AND rl.response_id = requests.id
          # rubocop:enable Layout/LineLength
          # rubocop:todo Layout/LineLength
          #        JOIN offers o ON rl.source_type = 'BetterTogether::Joatu::Offer' AND rl.source_id = offers.id
          # rubocop:enable Layout/LineLength
          join_on_rl = rl[:response_type].eq(BetterTogether::Joatu::Request.name).and(rl[:response_id].eq(requests[:id]))
          join_on_offers = rl[:source_type].eq(BetterTogether::Joatu::Offer.name).and(rl[:source_id].eq(offers[:id]))

          join_sources = requests.join(rl, Arel::Nodes::InnerJoin).on(join_on_rl).join(offers, Arel::Nodes::InnerJoin).on(join_on_offers).join_sources

          response_to_my_offer = scope.joins(join_sources).where(offers[:creator_id].eq(agent_id))

          # rubocop:todo Layout/LineLength
          scope.where(id: not_responses.select(:id)).or(scope.where(id: owned.select(:id))).or(scope.where(id: response_to_my_offer.select(:id)))
          # rubocop:enable Layout/LineLength
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
