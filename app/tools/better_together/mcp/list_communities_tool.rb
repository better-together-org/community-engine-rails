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
      end

      # List communities with authorization and privacy filtering
      # @param privacy_filter [String, nil] Optional privacy level filter
      # @return [String] JSON array of community objects
      def call(privacy_filter: nil)
        # Execute in user's timezone for consistent date/time formatting
        with_timezone_scope do
          # Use policy_scope to automatically filter by:
          # - Privacy settings (public/private)
          # - User permissions (platform manager sees all)
          # - Community membership (members see their communities)
          communities = policy_scope(BetterTogether::Community)

          # Apply optional privacy filter
          communities = communities.where(privacy: privacy_filter) if privacy_filter.present?

          # Serialize communities to JSON
          JSON.generate(
            communities.map { |community| serialize_community(community) }
          )
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
          member_count: community.person_members.count,
          created_at: community.created_at.iso8601
        }
      end
    end
  end
end
