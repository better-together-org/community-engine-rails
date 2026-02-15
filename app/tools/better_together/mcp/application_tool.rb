# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Base class for all MCP tools in the Better Together engine
    # Provides Pundit authorization integration and timezone handling for privacy-aware AI interactions
    #
    # User identity is resolved securely via Warden/Devise session.
    # MCP clients without a browser session operate as anonymous users.
    #
    # @example Creating a privacy-aware tool
    #   class ListCommunitiesTool < BetterTogether::Mcp::ApplicationTool
    #     description "List communities accessible to the current user"
    #
    #     arguments do
    #       optional(:privacy_filter).filled(:string).description("Filter by privacy level")
    #     end
    #
    #     def call(privacy_filter: nil)
    #       with_timezone_scope do
    #         communities = policy_scope(BetterTogether::Community)
    #         communities = communities.where(privacy: privacy_filter) if privacy_filter
    #         JSON.generate(communities.map { |c| { id: c.id, name: c.name } })
    #       end
    #     end
    #   end
    class ApplicationTool < FastMcp::Tool
      include BetterTogether::Mcp::PunditIntegration
    end
  end
end

# Rails-friendly alias
module BetterTogether
  module ActionTool
    Base = BetterTogether::Mcp::ApplicationTool
  end
end
