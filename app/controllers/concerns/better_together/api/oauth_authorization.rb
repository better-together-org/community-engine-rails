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

        unless doorkeeper_token.acceptable?(required_scopes)
          render_insufficient_scope(required_scopes)
        end
      rescue StandardError => e
        # If scope verification fails (e.g., expired token), render forbidden
        Rails.logger.warn("OAuth scope verification failed: #{e.message}")
        render_insufficient_scope(required_scopes)
      end

      def render_insufficient_scope(required_scopes)
        errors = [build_insufficient_scope_error(required_scopes)]
        response_document = JSONAPI::ErrorsOperationResult.new(403, errors)
        render json: JSONAPI::ResourceSerializer.new(nil).serialize_errors(response_document.errors),
               status: :forbidden
      end

      def build_insufficient_scope_error(required_scopes)
        JSONAPI::Error.new(
          code: 'INSUFFICIENT_SCOPE',
          status: :forbidden,
          title: 'Insufficient OAuth scope',
          detail: "This action requires one of these scopes: #{required_scopes.join(', ')}",
          meta: { required_scopes: required_scopes, provided_scopes: token_scopes }
        )
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
