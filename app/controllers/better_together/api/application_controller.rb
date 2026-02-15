# frozen_string_literal: true

require_dependency 'jsonapi/resource_controller'

module BetterTogether
  # Base API controller for JSONAPI endpoints
  module Api
    # Base controller for Better Together JSONAPI endpoints.
    # Provides authentication via Devise JWT, authorization via Pundit,
    # and standardized error handling for all API controllers.
    class ApplicationController < ::JSONAPI::ResourceController
      include Pundit::Authorization
      include Pundit::ResourceController
      include BetterTogether::Api::OauthAuthorization

      protect_from_forgery with: :exception, unless: -> { request.format.json? || request.format == Mime[:jsonapi] }

      # Ensure authentication by default (controllers can skip if needed)
      # Support both Devise JWT and Doorkeeper OAuth2 tokens
      before_action :authenticate_user!, unless: :oauth2_authenticated?

      # Override JSONAPI's handle_exceptions to convert Pundit errors to 404
      def handle_exceptions(exception)
        case exception
        when Pundit::NotAuthorizedError
          # Return 404 instead of 403 for security (don't reveal resource existence)
          errors = [JSONAPI::Error.new(
            code: JSONAPI::RECORD_NOT_FOUND,
            status: :not_found,
            title: 'Record not found',
            detail: "The record identified by #{params[:id]} could not be found."
          )]
          response_document.add_result(JSONAPI::ErrorsOperationResult.new(404, errors), nil)
        else
          super
        end
      end

      private

      # Check if the current request is authenticated via OAuth2 token
      # @return [Boolean]
      def oauth2_authenticated?
        doorkeeper_token.present?
      rescue StandardError
        false
      end

      # Override current_user to support both Devise and Doorkeeper authentication
      # When an OAuth2 token is present with a resource_owner_id, resolve the user
      # For client_credentials tokens, resolve the user from the application owner
      def current_user
        if oauth2_authenticated? && doorkeeper_token.resource_owner_id.present?
          @current_user ||= BetterTogether::User.find_by(id: doorkeeper_token.resource_owner_id)
        elsif oauth2_authenticated?
          # client_credentials flow: resolve user from application owner (Person)
          @current_user ||= doorkeeper_token.application&.owner&.user
        else
          super
        end
      end

      # Pundit needs this method to get the current user for policy initialization
      # This method is called by Pundit to determine who to pass as the first argument to policies
      def pundit_user
        current_user
      end

      # Provide current person in JSONAPI context for resources that scope by participant
      # Resources can access this via options[:context][:current_person]
      # Merges with Pundit::ResourceController's context (current_user, policy_used)
      def context
        super.merge(current_person: current_user&.person)
      end

      # Check if this is a Devise controller (auth endpoints)
      def devise_controller?
        is_a?(Devise::SessionsController) ||
          is_a?(Devise::RegistrationsController) ||
          is_a?(Devise::PasswordsController) ||
          is_a?(Devise::ConfirmationsController)
      end
    end
  end
end
