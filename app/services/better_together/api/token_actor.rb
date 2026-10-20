# frozen_string_literal: true

module BetterTogether
  module Api
    # Who an OAuth bearer token acts as. Built only from the token (never from
    # params or headers) and shared by the REST API and MCP. Only credentials
    # bound to a Robot produce an actor; other applications keep acting as
    # their owner and resolve to nil here.
    class TokenActor
      READ_PREFIX = /\Aread/
      WRITE_PREFIX = /\A(write|admin)/

      attr_reader :robot, :operator, :application, :community, :grant, :token_scopes

      def self.from_token(token)
        application = token&.application
        return nil unless application&.agent?

        new(token:, application:)
      end

      def initialize(token:, application:)
        @application = application
        @robot = application.robot
        @community = application.community
        @token_scopes = token.scopes.to_a
        @grant = find_grant
        @operator = @grant&.operator
      end

      def active?
        grant.present? && operator&.user.present? && robot&.active != false
      end

      # Token scopes narrowed to what the live grant carries.
      def scopes
        return [] unless active?

        token_scopes & grant.scopes.to_a
      end

      def allows_any?(required)
        scopes.intersect?(Array(required).map(&:to_s))
      end

      def allows_http_method?(http_method)
        pattern = http_method.to_s.upcase.in?(%w[GET HEAD OPTIONS]) ? READ_PREFIX : WRITE_PREFIX
        scopes.any? { |scope| scope.match?(pattern) }
      end

      def user
        operator&.user
      end

      # Attaches this actor to Current so authorization is bounded by the
      # credential for the rest of the request.
      def apply_to_current!
        Current.token_actor = self
        Current.robot = robot
        Current.person = operator
        Current.agent = robot
        Current.credential_community = community
        Current.platform = application.platform
      end

      private

      def find_grant
        candidates = AgentGrant.active.where(robot_id: robot.id, platform_id: application.platform_id)
        candidates.where(community_id: [community&.id, nil].uniq).order(Arel.sql('community_id IS NULL')).first
      end
    end
  end
end
