# frozen_string_literal: true

module BetterTogether
  # Base application controller for engine
  class ApplicationController < ActionController::Base
    include ActiveStorage::SetCurrent
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :check_platform_setup
    before_action :set_locale

    rescue_from ActiveRecord::RecordNotFound, with: :render_404 # rubocop:todo Naming/VariableNumber
    rescue_from ActionController::RoutingError, with: :render_404 # rubocop:todo Naming/VariableNumber
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from StandardError, with: :handle_error # Add this line

    private

    def check_platform_setup
      host_platform = helpers.host_platform

      return unless !host_platform.persisted? && !helpers.host_setup_wizard.completed?

      redirect_to setup_wizard_path
    end

    def render_404 # rubocop:todo Naming/VariableNumber
      render 'errors/404', status: :not_found
    end

    def user_not_authorized(exception)
      exception.policy.class.to_s.underscore

      flash[:error] = exception.message
      redirect_back(fallback_location: main_app.root_path)
    end

    def handle_error(exception)
      # rubocop:todo Layout/LineLength

      # call error reporting
      error_reporting(exception)

      flash.now[:error] = exception.message # Set the exception message as an error flash message for the current request
      # rubocop:enable Layout/LineLength
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('flash_messages',
                                                    # rubocop:todo Layout/LineLength
                                                    partial: 'layouts/better_together/flash_messages', locals: { flash: })
          # rubocop:enable Layout/LineLength
        end
        format.html { render 'errors/500', status: :internal_server_error }
      end
    end

    def default_url_options
      { locale: I18n.locale }
    end

    def set_locale
      I18n.locale = params[:locale] || I18n.default_locale
    end

    protected

    def error_reporting(exception); end
  end
end
