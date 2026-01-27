# frozen_string_literal: true

module BetterTogether
  module Mcp
    # Provides Pundit user context for MCP tools and resources
    # Wraps a User record to make it compatible with Pundit authorization
    class PunditContext
      attr_reader :user

      # Create context from Rack request
      # @param request [Rack::Request] The HTTP request
      # @return [PunditContext] Context with user from request params
      def self.from_request(request)
        user_id = request.params['user_id']
        user = user_id.present? ? BetterTogether::User.find_by(id: user_id) : nil
        new(user: user)
      end

      # Initialize with user
      # @param user [User, nil] The authenticated user or nil for anonymous
      def initialize(user:)
        @user = user
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
