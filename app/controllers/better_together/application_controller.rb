# frozen_string_literal: true

module BetterTogether
  # Base application controller for engine
  class ApplicationController < ActionController::Base
    include ActiveStorage::SetCurrent
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :check_platform_setup
    around_action :with_locale
    before_action :store_user_location!, if: :storable_location?
    # The callback which stores the current location must be added before you authenticate the user 
    # as `authenticate_user!` (or whatever your resource is) will halt the filter chain and redirect 
    # before the location can be stored.

    rescue_from ActiveRecord::RecordNotFound, with: :handle404
    rescue_from ActionController::RoutingError, with: :handle404
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from StandardError, with: :handle_error # Add this line

    protected

    def check_platform_setup
      host_platform = helpers.host_platform

      return unless !host_platform.persisted? && !helpers.host_setup_wizard.completed?

      redirect_to setup_wizard_path
    end

    def handle404
      render_404
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

      raise exception if Rails.env.development?

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

    def default_url_options(_options = {}) # rubocop:todo Lint/UnderscorePrefixedVariableName
      { locale: _options[:locale] || I18n.locale }
    end

    def error_reporting(exception); end

    # Extract language from request header
    def extract_locale_from_accept_language_header
      return unless request.env['HTTP_ACCEPT_LANGUAGE']

      lg = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first.to_sym
      lg.in?(I18n.available_locales) ? lg : nil
    end

    def with_locale(&)
      locale = params[:locale] || # Request parameter
               #  (current_user.preferred_locale if user_signed_in?) ||  # Model saved configuration
               extract_locale_from_accept_language_header || # Language header - browser config
               I18n.default_locale # Set in your config files, english by super-default

      I18n.with_locale(locale, &)
    end

    def self.default_url_options(options={})
      options.merge({ :locale => I18n.locale })
    end

    # Its important that the location is NOT stored if:
    # - The request method is not GET (non idempotent)
    # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an 
    #    infinite redirect loop.
    # - The request is an Ajax request as this can lead to very unexpected behaviour.
    # - The request is not a Turbo Frame request ([turbo-rails](https://github.com/hotwired/turbo-rails/blob/main/app/controllers/turbo/frames/frame_request.rb))
    def storable_location?
      request.get? &&
        is_navigational_format? &&
        !devise_controller? &&
        !request.xhr? &&
        !turbo_frame_request?
    end

    def store_user_location!
      # :user is the scope we are authenticating
      store_location_for(:user, request.fullpath)
    end

    def after_sign_in_path_for(resource_or_scope)
      stored_location_for(resource_or_scope)
    end
  end
end
