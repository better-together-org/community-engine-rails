module BetterTogether
  class ApplicationController < ActionController::Base
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :check_platform_setup

    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    rescue_from ActionController::RoutingError, with: :render_404
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    # rescue_from Exception, with: :render_500

    private

    def check_platform_setup
      host_platform = helpers.host_platform

      if !host_platform.persisted? && !helpers.host_setup_wizard.completed?
        redirect_to setup_wizard_path
      end
    end

    def render_404
      render 'errors/404', status: :not_found
    end
  
    def render_500
      render 'errors/500', status: :internal_server_error
    end

    def user_not_authorized(exception)
      policy_name = exception.policy.class.to_s.underscore
   
      flash[:error] = exception.message
      # flash[:error] = t "#{policy_name}.#{exception.query}", scope: "pundit", default: :default
      redirect_back(fallback_location: main_app.root_path)
    end
  end
end
