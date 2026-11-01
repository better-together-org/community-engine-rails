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
      attr_reader :user, :actor

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

        token = doorkeeper_token_from(request)
        context = agent_context_for(token) || context_for_owner(token) || context
        context.sync_current!
        context
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
        context_for_owner(doorkeeper_token_from(request))&.user
      end
      private_class_method :extract_user_from_doorkeeper

      # Accessible bearer token carrying the 'mcp_access' scope, or nil.
      def self.doorkeeper_token_from(request)
        return nil unless defined?(Doorkeeper)

        # FastMCP passes a Rack::Request which lacks the #authorization helper
        # that ActionDispatch::Request provides. Wrap it so Doorkeeper can read
        # the Authorization header via the standard Rack env key.
        doorkeeper_request = if request.respond_to?(:authorization)
                               request
                             else
                               ActionDispatch::Request.new(request.env)
                             end

        token = Doorkeeper::OAuth::Token.authenticate(doorkeeper_request, :from_bearer_authorization)
        token if token&.accessible? && token.acceptable?('mcp_access')
      end
      private_class_method :doorkeeper_token_from

      def self.context_for_owner(token)
        return nil unless token

        user = BetterTogether::User.find_by(id: token.resource_owner_id)
        user ? new(user: user) : nil
      end
      private_class_method :context_for_owner

      # Agent credentials act as their operator, bounded by the grant. A robot
      # credential without a live grant covering mcp_access stays anonymous.
      def self.agent_context_for(token)
        actor = BetterTogether::Api::TokenActor.from_token(token)
        return nil unless actor
        return new(user: nil) unless actor.active? && actor.allows_any?('mcp_access')

        new(user: actor.user, actor: actor)
      end
      private_class_method :agent_context_for

      # Initialize with user
      # @param user [User, nil] The authenticated user or nil for anonymous
      # @param actor [BetterTogether::Api::TokenActor, nil] Agent credential, if any
      def initialize(user:, actor: nil)
        @user = user
        @actor = actor
      end

      # Makes Current reflect this request's credential (and clears any left
      # over from a previous request on the same thread).
      def sync_current!
        if actor
          actor.apply_to_current!
        else
          Current.token_actor = nil
          Current.credential_community = nil
          Current.robot = nil
        end
      end

      # Anonymous MCP clients (no browser session and no OAuth context)
      # should be treated as guests.
      # @return [Boolean]
      def guest?
        user.nil?
      end

      # ApplicationPolicy and its Scope classes gate anonymous-vs-authenticated
      # logic throughout the app via `user.present?`/`user.blank?`. pundit_user
      # here is always this PunditContext instance itself, never nil — without
      # this override, `present?` would always be true (a non-nil object),
      # silently defeating every "unless user.present?" anonymous guard for MCP
      # requests. Delegate blank?/present? to the wrapped user instead.
      # @return [Boolean]
      def blank?
        user.blank?
      end

      # @return [Boolean]
      def present?
        !blank?
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
