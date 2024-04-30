module BetterTogether
  # Base application controller for engine
  class ApplicationController < ActionController::Base
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :check_platform_setup

    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    rescue_from ActionController::RoutingError, with: :render_404
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from StandardError, with: :handle_error # Add this line

    private

    def check_platform_setup
      host_platform = helpers.host_platform

      return unless !host_platform.persisted? && !helpers.host_setup_wizard.completed?

      redirect_to setup_wizard_path
    end

    def render_404
      render 'errors/404', status: :not_found
    end

    def user_not_authorized(exception)
      exception.policy.class.to_s.underscore

      flash[:error] = exception.message
      redirect_back(fallback_location: main_app.root_path)
    end

    def handle_error(exception)
      flash.now[:error] = exception.message # Set the exception message as an error flash message for the current request
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages', locals: { flash: flash })
        end
        format.html { render 'errors/500', status: :internal_server_error }
      end
    end
    
  end
end
