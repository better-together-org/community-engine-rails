# frozen_string_literal: true

module BetterTogether
  # Base application controller for engine
  class ApplicationController < ActionController::Base
    include ActiveStorage::SetCurrent
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :check_platform_setup
    before_action :set_locale
    before_action :store_user_location!, if: :storable_location?
    before_action :check_platform_privacy
    # The callback which stores the current location must be added before you authenticate the user
    # as `authenticate_user!` (or whatever your resource is) will halt the filter chain and redirect
    # before the location can be stored.

    before_action do
      Rack::MiniProfiler.authorize_request if current_user&.permitted_to?('manage_platform')
    end

    rescue_from ActiveRecord::RecordNotFound, with: :handle404
    rescue_from ActionController::RoutingError, with: :handle404
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from StandardError, with: :handle_error

    helper_method :default_url_options

    def self.default_url_options
      super.merge(locale: I18n.locale)
    end

    def default_url_options
      super.merge(locale: I18n.locale)
    end

    protected

    def bot_request?
      user_agent = request.user_agent&.downcase

      # List of common bot User-Agents
      bots = %w[
        googlebot bingbot slurp duckduckbot baiduspider yandexbot sogou
        exabot facebookexternalhit facebot ia_archiver betteruptime uptimerobot
      ]

      bots.any? { |bot| user_agent&.include?(bot) }
    end

    def check_platform_setup
      host_platform = helpers.host_platform

      return unless !host_platform.persisted? && !helpers.host_setup_wizard.completed?

      redirect_to setup_wizard_path
    end

    def check_platform_privacy
      return if helpers.host_platform.privacy_public?
      return if current_user

      flash[:error] = I18n.t('globals.platform_not_public')
      redirect_to new_user_session_path(locale: I18n.locale)
    end

    def handle404
      render_404
    end

    def render_404 # rubocop:todo Naming/VariableNumber
      render 'errors/404', status: :not_found
    end

    def user_not_authorized(exception)
      action_name = exception.query.to_s.chomp('?')
      resource_name = if exception.record.is_a? Class
                        exception.record.name.underscore.pluralize
                      else
                        exception.record.class.to_s.underscore
                      end

      # Use I18n to build the message
      message = I18n.t("pundit.errors.#{action_name}", resource: resource_name.humanize)

      if request.format.turbo_stream?
        flash.now[:error] = message # Use flash.now for Turbo Stream requests
        render turbo_stream: [
          turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                 locals: { flash: })
        ]
      else
        flash[:error] = message # Use flash for regular redirects
        redirect_back(fallback_location: home_page_path)
      end
    end

    def handle_error(exception)
      return user_not_authorized(exception) if exception.is_a?(Pundit::NotAuthorizedError)
      raise exception if Rails.env.development?

      # call error reporting
      error_reporting(exception)

      respond_to do |format|
        format.turbo_stream do
          flash.now[:error] = exception.message # Set the exception message as an error flash message for the current request
          render turbo_stream: turbo_stream.replace('flash_messages',
                                                    # rubocop:todo Layout/LineLength
                                                    partial: 'layouts/better_together/flash_messages', locals: { flash: })
          # rubocop:enable Layout/LineLength
        end
        format.html do
          flash[:error] = exception.message
          render 'errors/500', status: :internal_server_error
        end
      end
    end

    def error_reporting(exception); end

    # Extract language from request header
    def extract_locale_from_accept_language_header
      return unless request.env['HTTP_ACCEPT_LANGUAGE']

      lg = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first.to_sym
      lg.in?(I18n.available_locales) ? lg : nil
    end

    def set_locale
      locale = params[:locale] || # Request parameter
               #  (current_user.preferred_locale if user_signed_in?) ||  # Model saved configuration
               extract_locale_from_accept_language_header || # Language header - browser config
               I18n.default_locale # Set in your config files, english by super-default

      I18n.locale = locale
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
