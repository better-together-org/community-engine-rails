# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list communities with privacy-aware filtering
    # Respects Pundit authorization and Privacy concern settings
    class ListCommunitiesTool < ApplicationTool
      description 'List communities accessible to the current user, respecting privacy settings and permissions'

      arguments do
        optional(:privacy_filter)
          .filled(:string)
          .description('Filter by privacy level: public or private')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 50)')
      end

      # List communities with authorization and privacy filtering
      # @param privacy_filter [String, nil] Optional privacy level filter
      # @param limit [Integer] Maximum results (default: 50, max: 100)
      # @return [String] JSON array of community objects
      def call(privacy_filter: nil, limit: 50)
        # Execute in user's timezone for consistent date/time formatting
        with_timezone_scope do
          # Use policy_scope to automatically filter by:
          # - Privacy settings (public/private)
          # - User permissions (platform manager sees all)
          # - Community membership (members see their communities)
          communities = policy_scope(BetterTogether::Community)
                        .includes(:person_community_memberships)

          # Apply optional privacy filter
          communities = communities.where(privacy: privacy_filter) if privacy_filter.present?

          # Apply limit with a maximum cap
          communities = communities.limit([limit, 100].min)

          # Serialize communities to JSON
          result = JSON.generate(
            communities.map { |community| serialize_community(community) }
          )

          log_invocation('list_communities', { privacy_filter: privacy_filter }, result.bytesize)
          result
        end
      end

      private

      # Serialize a community to a hash
      # @param community [BetterTogether::Community] The community to serialize
      # @return [Hash] Serialized community data
      def serialize_community(community)
        {
          id: community.id,
          name: community.name,
          description: community.description,
          privacy: community.privacy,
          slug: community.slug,
          member_count: community.person_community_memberships.size,
          created_at: community.created_at.in_time_zone.iso8601
        }
      end
    end
  end
end
