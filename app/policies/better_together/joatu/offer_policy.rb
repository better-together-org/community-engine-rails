# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Offer
    class OfferPolicy < PlatformRecordPolicy
      # Public offers are browseable without authentication; Scope filters to public-only for guests.
      def index? = true

      def show?
        scope_allows_record?
      end

      def create? = user.present?
      alias new? create?

      # Permission helper for the "respond with request" flow (creating an Offer from a Request)
      def respond_with_request? = create?

      def update?
        return false unless user.present?

        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform') || record.creator_id == agent&.id
      end
      alias edit? update?

      def destroy?
        return false unless user.present?

        # Prevent destroy if there are any agreements for this offer — applies to everyone
        return false if record.respond_to?(:agreements) && record.agreements.exists?

        # Platform stewards or the creator may destroy when there are no agreements
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform') || record.creator_id == agent&.id
      end

      class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
        # rubocop:todo Metrics/MethodLength
        def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          return scope.none unless current_platform

          # Platform stewards see everything on the platform
          if user.present? && (permitted_to?('manage_platform_settings') || permitted_to?('manage_platform'))
            return platform_scoped
          end

          # Standalone offers: not a response to another resource (no inbound ResponseLink)
          # rubocop:todo Layout/LineLength
          standalone = platform_scoped.left_joins(:response_links_as_response)
                                      .where(better_together_joatu_response_links: { id: nil })
          # rubocop:enable Layout/LineLength

          # Unauthenticated: public standalone offers only, no blocking to apply
          return standalone.where(privacy: 'public') unless user.present?

          agent_id = agent.id

          # Authenticated: public + community-privacy standalone offers visible to all platform members
          # rubocop:todo Layout/LineLength
          community_visible = standalone.where(privacy: %w[public community])
          # rubocop:enable Layout/LineLength

          # Offers owned by the agent (any privacy, including private)
          owned = platform_scoped.where(creator_id: agent_id)

          # Offers that are responses to a Request where that Request's creator is the agent
          rl       = BetterTogether::Joatu::ResponseLink.arel_table
          offers   = BetterTogether::Joatu::Offer.arel_table
          requests = BetterTogether::Joatu::Request.arel_table

          # rubocop:todo Layout/LineLength
          # JOIN response_links rl ON rl.response_type = 'BetterTogether::Joatu::Offer' AND rl.response_id = offers.id
          # rubocop:enable Layout/LineLength
          #   JOIN requests r ON rl.source_type = 'BetterTogether::Joatu::Request' AND rl.source_id = requests.id
          join_on_rl       = rl[:response_type].eq(BetterTogether::Joatu::Offer.name).and(rl[:response_id].eq(offers[:id]))
          join_on_requests = rl[:source_type].eq(BetterTogether::Joatu::Request.name).and(rl[:source_id].eq(requests[:id]))
          join_sources     = offers.join(rl, Arel::Nodes::InnerJoin).on(join_on_rl)
                                   .join(requests, Arel::Nodes::InnerJoin).on(join_on_requests)
                                   .join_sources

          response_to_my_request = platform_scoped.joins(join_sources).where(requests[:creator_id].eq(agent_id))

          # rubocop:todo Layout/LineLength
          result = platform_scoped.where(id: community_visible.select(:id))
                                  .or(platform_scoped.where(id: owned.select(:id)))
                                  .or(platform_scoped.where(id: response_to_my_request.select(:id)))
          # rubocop:enable Layout/LineLength

          exclude_blocked_creators(result)
        end
        # rubocop:enable Metrics/MethodLength

        private

        # Filter out offers created by people the agent has blocked or been blocked by.
        def exclude_blocked_creators(relation)
          blocked_ids = agent.person_blocks.pluck(:blocked_id)
          blocker_ids = BetterTogether::PersonBlock.where(blocked_id: agent.id).pluck(:blocker_id)
          excluded    = (blocked_ids + blocker_ids).uniq
          excluded.empty? ? relation : relation.where.not(creator_id: excluded)
        end
      end

      private

      def scope_allows_record?
        self.class::Scope.new(user, record.class).resolve.where(id: record.id).exists?
      end
    end
  end
end
