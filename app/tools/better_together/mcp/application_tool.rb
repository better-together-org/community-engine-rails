# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Base class for all MCP tools in the Better Together engine
    # Provides Pundit authorization integration and timezone handling for privacy-aware AI interactions
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
      include Pundit::Authorization
      include BetterTogether::TimezoneScoped

      protected

      # Returns Pundit user context from the current request
      # This enables Pundit authorization in tools
      # @return [BetterTogether::Mcp::PunditContext] Context with current user
      def pundit_user
        @pundit_user ||= BetterTogether::Mcp::PunditContext.from_request(request)
      end

      # Get the current authenticated user
      # @return [User, nil] The authenticated user or nil
      def current_user
        pundit_user.user
      end

      # Get the current person (agent) associated with the user
      # @return [BetterTogether::Person, nil] The person or nil
      def agent
        pundit_user.agent
      end

      # Override request to make it available from FastMcp context
      # FastMcp provides this through the tool's execution context
      # @return [Rack::Request] The HTTP request
      def request
        # This will be provided by FastMcp when tool is executed
        # During tests, we stub this method
        @request || super
      end
    end
  end
end

# Rails-friendly alias
module BetterTogether
  module ActionTool
    Base = BetterTogether::Mcp::ApplicationTool
  end
end
