# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Shared concern providing Pundit authorization integration for MCP tools and resources
    # Includes user context resolution, current user access, and timezone handling
    #
    # @example Including in a tool or resource base class
    #   class ApplicationTool < FastMcp::Tool
    #     include BetterTogether::Mcp::PunditIntegration
    #   end
    module PunditIntegration
      extend ActiveSupport::Concern

      # Include Pundit::Authorization at the module level so it appears BELOW
      # PunditIntegration in the ancestor chain. This ensures our pundit_user
      # override takes precedence over Pundit's default (which returns current_user).
      include Pundit::Authorization

      included do
        include BetterTogether::TimezoneScoped
      end

      protected

      # Build PunditContext from the current MCP request's Warden session.
      # Memoized to avoid repeated lookups during a single tool/resource call.
      # @return [BetterTogether::Mcp::PunditContext] Context with current user
      def mcp_pundit_context
        @mcp_pundit_context ||= BetterTogether::Mcp::PunditContext.from_request(request)
      end

      # Override Pundit's pundit_user to return our MCP-specific PunditContext.
      # IMPORTANT: This breaks the default Pundit cycle where pundit_user calls current_user.
      # We return the PunditContext directly (which Pundit uses for policy resolution).
      # @return [BetterTogether::Mcp::PunditContext] Context for Pundit policy lookups
      def pundit_user
        mcp_pundit_context
      end

      # Get the current authenticated user from the MCP request Warden session.
      # Does NOT call pundit_user to avoid infinite recursion with Pundit::Authorization.
      # @return [User, nil] The authenticated user or nil for anonymous access
      def current_user
        mcp_pundit_context.user
      end

      # Get the current person (agent) associated with the user
      # @return [BetterTogether::Person, nil] The person or nil
      def agent
        mcp_pundit_context.agent
      end

      # Override request to make it available from FastMcp context
      # FastMcp provides this through the tool/resource execution context
      # @return [Rack::Request] The HTTP request
      def request
        @request || super
      end
    end
  end
end
