# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Provides Pundit user context for MCP tools and resources
    # Wraps a User record to make it compatible with Pundit authorization
    #
    # User identity is resolved securely via Warden/Devise session.
    # MCP clients without a browser session operate as anonymous users
    # and see only public data controlled by Pundit policies.
    #
    # SECURITY: Never trust user identity from client-supplied params or headers.
    # The MCP auth_token provides transport-level access control but does NOT
    # identify individual users.
    class PunditContext
      attr_reader :user

      # Create context from Rack request using Warden/Devise session
      # @param request [Rack::Request] The HTTP request
      # @return [PunditContext] Context with authenticated user or anonymous
      def self.from_request(request)
        user = extract_user_from_warden(request)
        new(user: user)
      end

      # Create context from Rack request, trying Warden first, then falling back
      # to Doorkeeper OAuth2 bearer token. This consolidates the authentication
      # logic previously duplicated in fast_mcp.rb filter blocks.
      # @param request [Rack::Request] The HTTP request
      # @return [PunditContext] Context with authenticated user or anonymous
      def self.from_request_or_doorkeeper(request)
        context = from_request(request)
        return context if context.authenticated?

        user = extract_user_from_doorkeeper(request)
        user ? new(user: user) : context
      end

      # Extract authenticated user from Warden session
      # @param request [Rack::Request] The HTTP request
      # @return [User, nil] The authenticated user or nil for anonymous access
      def self.extract_user_from_warden(request)
        return nil unless request.respond_to?(:env)

        warden = request.env['warden']
        return nil unless warden

        warden.user
      end
      private_class_method :extract_user_from_warden

      # Extract authenticated user from Doorkeeper OAuth2 bearer token.
      # Only accepts tokens with the 'mcp_access' scope.
      # @param request [Rack::Request] The HTTP request
      # @return [User, nil] The resource owner or nil
      def self.extract_user_from_doorkeeper(request)
        return nil unless defined?(Doorkeeper)

        token = Doorkeeper::OAuth::Token.authenticate(request, :from_bearer_authorization)
        return nil unless token&.accessible? && token.acceptable?('mcp_access')

        BetterTogether::User.find_by(id: token.resource_owner_id)
      end
      private_class_method :extract_user_from_doorkeeper

      # Initialize with user
      # @param user [User, nil] The authenticated user or nil for anonymous
      def initialize(user:)
        @user = user
      end

      # Anonymous MCP clients (no browser session and no OAuth context)
      # should be treated as guests.
      # @return [Boolean]
      def guest?
        user.nil?
      end

      # Convenience predicate
      # @return [Boolean]
      def authenticated?
        !guest?
      end

      # Get the Person (agent) associated with the user
      # @return [BetterTogether::Person, nil] The person or nil if no user
      def agent
        user&.person
      end

      # Alias for agent - provides compatibility with ApplicationPolicy
      # @return [BetterTogether::Person, nil] The person or nil if no user
      alias person agent

      # Check if user has permission
      # Delegates to agent.permitted_to? which checks role permissions
      # @param permission_identifier [String] Permission identifier (e.g., 'manage_platform')
      # @param record [ActiveRecord::Base, nil] Optional record to check permission against
      # @return [Boolean] True if permitted, false otherwise
      def permitted_to?(permission_identifier, record = nil)
        return false unless agent

        agent.permitted_to?(permission_identifier, record)
      end
    end
  end
end
