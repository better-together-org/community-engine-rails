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

      protect_from_forgery with: :exception, unless: -> { request.format.json? || request.format == Mime[:jsonapi] }

      # Ensure authentication by default (controllers can skip if needed)
      before_action :authenticate_user!

      # Override JSONAPI's handle_exceptions to convert Pundit errors to 404
      def handle_exceptions(e)
        case e
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

      # Pundit needs this method to get the current user for policy initialization
      # This method is called by Pundit to determine who to pass as the first argument to policies
      def pundit_user
        current_user
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
