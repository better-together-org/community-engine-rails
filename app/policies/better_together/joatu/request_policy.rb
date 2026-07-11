# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Request
    class RequestPolicy < PlatformRecordPolicy
      # Public requests are browseable without authentication; Scope filters to public-only for guests.
      # ConnectionRequests and MembershipRequests are always excluded from the public path.
      def index? = true

      def show?
        # Connection requests remain authentication-gated regardless of privacy
        return false if connection_request? && !user.present?
        return can_view_network_request? if connection_request?

        scope_allows_record?
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

      class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
        MEMBERSHIP_REQUEST_TYPE   = 'BetterTogether::Joatu::MembershipRequest'
        CONNECTION_REQUEST_TYPE   = 'BetterTogether::Joatu::ConnectionRequest'
        PRIVATE_REQUEST_TYPES     = [MEMBERSHIP_REQUEST_TYPE, CONNECTION_REQUEST_TYPE].freeze

        # rubocop:todo Metrics/MethodLength
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          return scope.none unless current_platform

          # MembershipRequests and ConnectionRequests are always private subtypes.
          # Exclude them from any base query; they have their own policy scopes.
          base = platform_scoped.where.not(type: PRIVATE_REQUEST_TYPES)

          # Platform managers / joatu managers see everything
          if user.present?
            return base                   if permitted_to?('manage_platform')
            return platform_scoped        if can_manage_joatu?
            return platform_scoped        if can_manage_network_connections? && connection_request_scope?
          end

          # Standalone requests: not a response to another resource
          # rubocop:todo Layout/LineLength
          standalone = base.left_joins(:response_links_as_response)
                           .where(better_together_joatu_response_links: { id: nil })
          # rubocop:enable Layout/LineLength

          # Unauthenticated: public standalone requests only, no blocking to apply
          return standalone.where(privacy: 'public') unless user.present?

          agent_id = agent.id

          # Authenticated: public + community-privacy standalone requests visible to all platform members
          community_visible = standalone.where(privacy: %w[public community])

          # Requests owned by the agent (any privacy, including private)
          owned = base.where(creator_id: agent_id)

          # Requests that are responses to an Offer owned by the agent
          rl       = BetterTogether::Joatu::ResponseLink.arel_table
          offers   = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          # rubocop:todo Layout/LineLength
          # JOIN response_links rl ON rl.response_type = 'BetterTogether::Joatu::Request' AND rl.response_id = requests.id
          # rubocop:enable Layout/LineLength
          #   JOIN offers o ON rl.source_type = 'BetterTogether::Joatu::Offer' AND rl.source_id = offers.id
          join_on_rl     = rl[:response_type].eq(BetterTogether::Joatu::Request.name).and(rl[:response_id].eq(requests[:id]))
          join_on_offers = rl[:source_type].eq(BetterTogether::Joatu::Offer.name).and(rl[:source_id].eq(offers[:id]))
          join_sources   = requests.join(rl, Arel::Nodes::InnerJoin).on(join_on_rl)
                                   .join(offers, Arel::Nodes::InnerJoin).on(join_on_offers)
                                   .join_sources

          response_to_my_offer = base.joins(join_sources).where(offers[:creator_id].eq(agent_id))

          # rubocop:todo Layout/LineLength
          result = base.where(id: community_visible.select(:id))
                       .or(base.where(id: owned.select(:id)))
                       .or(base.where(id: response_to_my_offer.select(:id)))
          # rubocop:enable Layout/LineLength

          exclude_blocked_creators(result)
        end
        # rubocop:enable Metrics/MethodLength

        private

        # Filter out requests created by people the agent has blocked or been blocked by.
        def exclude_blocked_creators(relation)
          blocked_ids = agent.person_blocks.pluck(:blocked_id)
          blocker_ids = BetterTogether::PersonBlock.where(blocked_id: agent.id).pluck(:blocker_id)
          excluded    = (blocked_ids + blocker_ids).uniq
          excluded.empty? ? relation : relation.where.not(creator_id: excluded)
        end

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

      def scope_allows_record?
        self.class::Scope.new(user, record.class).resolve.where(id: record.id).exists?
      end
    end
  end
end
