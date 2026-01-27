# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Base class for all MCP resources in the Better Together engine
    # Provides Pundit authorization integration and timezone handling for privacy-aware data exposure
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
    #           .where(privacy: 'public')\n        \n        JSON.generate({
    #           communities: communities.map { |c| serialize_community(c) }
    #         })
    #       end
    #     end
    #
    #     private
    #
    #     def serialize_community(community)
    #       {
    #         id: community.id,
    #         name: community.name,
    #         description: community.description
    #       }
    #     end
    #   end
    class ApplicationResource < FastMcp::Resource
      include Pundit::Authorization
      include BetterTogether::TimezoneScoped

      protected

      # Returns Pundit user context from the current request
      # This enables Pundit authorization in resources
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
      # FastMcp provides this through the resource's execution context
      # @return [Rack::Request] The HTTP request
      def request
        # This will be provided by FastMcp when resource is accessed
        # During tests, we stub this method
        @request || super
      end
    end
  end
end

# Rails-friendly alias
module BetterTogether
  module ActionResource
    Base = BetterTogether::Mcp::ApplicationResource
  end
end
