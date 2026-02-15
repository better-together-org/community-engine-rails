# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Base class for all MCP resources in the Better Together engine
    # Provides Pundit authorization integration and timezone handling for privacy-aware data exposure
    #
    # User identity is resolved securely via Warden/Devise session.
    # MCP clients without a browser session operate as anonymous users.
    #
    # @example Creating a privacy-aware resource
    #   class PublicCommunitiesResource < BetterTogether::Mcp::ApplicationResource
    #     uri "bettertogether://communities/public"
    #     resource_name "Public Communities"
    #     mime_type "application/json"
    #
    #     def content
    #       with_timezone_scope do
    #         communities = policy_scope(BetterTogether::Community)
    #           .where(privacy: 'public')
    #
    #         JSON.generate({
    #           communities: communities.map { |c| serialize_community(c) }
    #         })
    #       end
    #     end
    #   end
    class ApplicationResource < FastMcp::Resource
      include BetterTogether::Mcp::PunditIntegration
    end
  end
end

# Rails-friendly alias
module BetterTogether
  module ActionResource
    Base = BetterTogether::Mcp::ApplicationResource
  end
end
