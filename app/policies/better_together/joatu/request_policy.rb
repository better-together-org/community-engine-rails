# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Request
    class RequestPolicy < ApplicationPolicy
      def index? = user.present?

      def show?
        return false unless user.present?

        return can_view_network_request? if connection_request?

        true
      end

      def create?
        return false unless user.present?

        return can_manage_network_connections? if connection_request?

        true
      end
      alias new? create?

      # Permission helper for the "respond with offer" flow (creating an Offer from a Request)
      def respond_with_offer? = create?

      def update?
        return false unless user.present?

        return can_manage_network_connections? if connection_request?

        can_manage_joatu? || record.creator_id == agent&.id
      end
      alias edit? update?
      alias matches? update?

      def destroy?
        return false unless user.present?

        # Prevent destroy if there are any agreements for this request — applies to everyone
        return false if record.respond_to?(:agreements) && record.agreements.exists?

        return can_manage_network_connections? if connection_request?

        can_manage_joatu? || record.creator_id == agent&.id
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        MEMBERSHIP_REQUEST_TYPE = 'BetterTogether::Joatu::MembershipRequest'

        # rubocop:todo Metrics/MethodLength
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          return scope.none unless user.present?

          # MembershipRequests are governed by MembershipRequestPolicy::Scope.
          # Exclude them here so they never leak through base Request queries.
          base = scope.where.not(type: MEMBERSHIP_REQUEST_TYPE)

          # Platform managers see everything
          return base.all if permitted_to?('manage_platform')
          return scope.all if can_manage_joatu?
          return scope.all if can_manage_network_connections? && connection_request_scope?

          agent_id = agent&.id

          # Requests that are not responses to another resource (no response_link where response is this request)
          # rubocop:todo Layout/LineLength
          not_responses = base.left_joins(:response_links_as_response).where(better_together_joatu_response_links: { id: nil })
          # rubocop:enable Layout/LineLength

          # Requests owned by the agent
          owned = base.where(creator_id: agent_id)

          # Requests that are responses to an Offer owned by the agent
          rl = BetterTogether::Joatu::ResponseLink.arel_table
          offers = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          # rubocop:todo Layout/LineLength
          # build: JOIN response_links rl ON rl.response_type = 'BetterTogether::Joatu::Request' AND rl.response_id = requests.id
          # rubocop:enable Layout/LineLength
          #        JOIN offers o ON rl.source_type = 'BetterTogether::Joatu::Offer' AND rl.source_id = offers.id
          join_on_rl = rl[:response_type].eq(BetterTogether::Joatu::Request.name).and(rl[:response_id].eq(requests[:id]))
          join_on_offers = rl[:source_type].eq(BetterTogether::Joatu::Offer.name).and(rl[:source_id].eq(offers[:id]))

          join_sources = requests.join(rl, Arel::Nodes::InnerJoin).on(join_on_rl).join(offers, Arel::Nodes::InnerJoin).on(join_on_offers).join_sources

          response_to_my_offer = base.joins(join_sources).where(offers[:creator_id].eq(agent_id))

          # rubocop:todo Layout/LineLength
          base.where(id: not_responses.select(:id)).or(base.where(id: owned.select(:id))).or(base.where(id: response_to_my_offer.select(:id)))
          # rubocop:enable Layout/LineLength
        end
        # rubocop:enable Metrics/MethodLength

        private

        def can_manage_joatu?
          permitted_to?('manage_joatu')
        end

        def can_manage_network_connections?
          permitted_to?('manage_network_connections')
        end

        def connection_request_scope?
          scope <= BetterTogether::Joatu::ConnectionRequest
        end
      end

      private

      def connection_request?
        record.is_a?(BetterTogether::Joatu::ConnectionRequest)
      end

      def can_manage_joatu?
        permitted_to?('manage_joatu')
      end

      def can_manage_network_connections?
        permitted_to?('manage_network_connections')
      end

      def can_view_network_request?
        can_manage_network_connections? || record.creator_id == agent&.id
      end
    end
  end
end
