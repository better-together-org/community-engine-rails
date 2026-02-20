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

      protected

      # Escape LIKE metacharacters (%, _) in user-supplied search queries
      # to prevent unintended pattern matching.
      # @param query [String] Raw user input
      # @return [String] Escaped query safe for use in LIKE clauses
      def sanitize_like(query)
        ActiveRecord::Base.sanitize_sql_like(query.to_s)
      end

      # Log MCP tool invocations for audit and debugging.
      # Produces structured JSON entries tagged [MCP][tool] in Rails logs.
      # Future: persist to Metrics::McpInvocation model for queryable audit trails.
      # @param tool_name [String] Name of the invoked tool
      # @param args [Hash] Arguments passed to the tool (sensitive keys stripped)
      # @param result_bytes [Integer] Size of the result payload
      def log_invocation(tool_name, args, result_bytes)
        Rails.logger.tagged('MCP', 'tool') do
          Rails.logger.info(
            {
              tool: tool_name,
              user_id: current_user&.id,
              person_id: agent&.id,
              args: args,
              result_bytes: result_bytes,
              timestamp: Time.current.iso8601
            }.to_json
          )
        end
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
