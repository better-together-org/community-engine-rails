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

      protect_from_forgery with: :exception, unless: -> { request.format.json? }

      # Ensure authentication by default (controllers can skip if needed)
      before_action :authenticate_user!

      # Ensure authorization is called on all actions
      after_action :verify_authorized, except: :index, unless: :devise_controller?
      after_action :verify_policy_scoped, only: :index, unless: :devise_controller?

      # Handle authorization failures
      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      # Render authorization error in JSONAPI format
      def user_not_authorized
        render jsonapi_errors: [{
          title: 'Not Authorized',
          detail: 'You are not authorized to perform this action',
          status: '403'
        }], status: :forbidden
      end

      # Provide context to JSONAPI resources and Pundit policies
      def context
        { user: current_user, agent: current_user&.person }
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
