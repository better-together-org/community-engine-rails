# frozen_string_literal: true

module BetterTogether
  module Api
    # Concern for OAuth2 scope-based authorization
    # Add to controllers to enforce OAuth scopes on specific actions
    module OauthAuthorization
      extend ActiveSupport::Concern

      included do
        before_action :verify_oauth_scopes, if: :oauth2_authenticated?
      end

      private

      def verify_oauth_scopes
        required_scopes = self.class.required_scopes_for_action(action_name)
        return if required_scopes.empty?

        # Check token validity first (expired, revoked)
        unless doorkeeper_token.accessible?
          render_token_invalid
          return
        end

        # Check if token has any of the required scopes
        unless doorkeeper_token.acceptable?(required_scopes)
          render_insufficient_scope(required_scopes)
        end
      rescue StandardError => e
        Rails.logger.warn("OAuth scope verification failed: #{e.message}")
        render_token_invalid
      end

      def render_token_invalid
        render json: {
          errors: [{
            status: '401',
            title: 'Unauthorized',
            detail: 'The access token is invalid, expired, or revoked.'
          }]
        }, status: :unauthorized
      end

      def render_insufficient_scope(required_scopes)
        render json: {
          errors: [{
            status: '403',
            title: 'Insufficient OAuth scope',
            detail: "This action requires one of these scopes: #{required_scopes.join(', ')}",
            meta: { required_scopes: required_scopes, provided_scopes: token_scopes }
          }]
        }, status: :forbidden
      end

      def token_scopes
        doorkeeper_token.scopes.to_a
      rescue StandardError
        []
      end

      # Class methods for defining required scopes
      class_methods do
        def require_oauth_scopes(*scopes, only: nil, except: nil)
          @required_oauth_scopes ||= {}
          actions = determine_target_actions(only, except)

          actions.each do |action|
            @required_oauth_scopes[action] = scopes
          end
        end

        def determine_target_actions(only, except)
          return Array(only).map(&:to_s) if only
          return all_actions_except(except) if except

          all_public_actions
        end

        def all_actions_except(excluded)
          all_public_actions - Array(excluded).map(&:to_s)
        end

        def all_public_actions
          instance_methods(false).grep(/\A(?!_)/).map(&:to_s)
        end

        def required_scopes_for_action(action)
          @required_oauth_scopes&.dig(action.to_s) || []
        end
      end
    end
  end
end
