# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Resource exposing public communities
    # Always returns only publicly accessible communities regardless of authentication
    class PublicCommunitiesResource < ApplicationResource
      uri 'bettertogether://communities/public'
      resource_name 'Public Communities'
      description 'List of all public communities on the platform'
      mime_type 'application/json'

      # Generate JSON content with public communities
      # Uses policy_scope to ensure privacy filtering
      # @return [String] JSON object with communities array
      def content
        # Execute in appropriate timezone for consistent date/time formatting
        with_timezone_scope do
          # Use policy_scope to get communities, then explicitly filter to public only
          # This ensures we only return public communities even if user is platform manager
          communities = policy_scope(BetterTogether::Community)
                        .where(privacy: 'public')
                        .order(created_at: :desc)

          JSON.generate({
                          communities: communities.map { |community| serialize_community(community) },
                          total: communities.count,
                          generated_at: Time.current.iso8601
                        })
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
          slug: community.slug,
          member_count: community.person_members.count,
          created_at: community.created_at.iso8601
        }
      end
    end
  end
end
