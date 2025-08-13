# frozen_string_literal: true

module BetterTogether
  # Base application controller for engine
  class ApplicationController < ActionController::Base # rubocop:todo Metrics/ClassLength
    include ActiveStorage::SetCurrent
    include PublicActivity::StoreController
    include Pundit::Authorization

    protect_from_forgery with: :exception

    layout :determine_layout

    before_action :check_platform_setup
    before_action :set_locale
    before_action :store_user_location!, if: :storable_location?

    before_action :set_platform_invitation
    before_action :check_platform_privacy
    # The callback which stores the current location must be added before you authenticate the user
    # as `authenticate_user!` (or whatever your resource is) will halt the filter chain and redirect
    # before the location can be stored.

    before_action do
      Rack::MiniProfiler.authorize_request if current_user&.permitted_to?('manage_platform')
    end

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::RoutingError, with: :render_not_found
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from StandardError, with: :handle_error

    helper_method :current_invitation, :default_url_options, :valid_platform_invitation_token_present?,
                  :turbo_native_app?

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

      return if host_platform.persisted? && helpers.host_setup_wizard.completed?

      redirect_to setup_wizard_path
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def set_platform_invitation # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # Only proceed if there's an invitation token in the URL or already in the session.
      return unless params[:invitation_code].present? || session[:platform_invitation_token].present?

      # Check if the session token has expired.
      if session[:platform_invitation_expires_at].present? && Time.current > session[:platform_invitation_expires_at]
        session.delete(:platform_invitation_token)
        session.delete(:platform_invitation_expires_at)
        return
      end

      token = if params[:invitation_code].present?
                # On first visit with the invitation code, update the session with the token and a new expiry.
                session[:platform_invitation_token] = params[:invitation_code]
              else
                # If no params, simply use the token stored in the session.
                session[:platform_invitation_token]
              end

      return unless token.present?

      @platform_invitation = ::BetterTogether::PlatformInvitation.pending.find_by(token: token)

      if @platform_invitation
        # Set the locale based on the invitation record
        I18n.locale = @platform_invitation.locale if @platform_invitation.locale.present?
        session[:locale] = I18n.locale
      else
        session.delete(:platform_invitation_token)
        session.delete(:platform_invitation_expires_at)
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def current_invitation
      @platform_invitation
    end

    def check_platform_privacy
      return if helpers.host_platform.privacy_public?
      return if current_user
      return unless BetterTogether.user_class.any?
      return if valid_platform_invitation_token_present?

      flash[:error] = I18n.t('globals.platform_not_public')
      redirect_to new_user_session_path(locale: I18n.locale)
    end

    def valid_platform_invitation_token_present?
      token = session[:platform_invitation_token]
      return false unless token.present?

      if session[:platform_invitation_expires_at].present? && Time.current > session[:platform_invitation_expires_at]
        return false
      end

      ::BetterTogether::PlatformInvitation.pending.exists?(token: token)
    end

    private

    def render_not_found
      render 'errors/404', status: :not_found
    end

    # rubocop:todo Metrics/MethodLength
    def user_not_authorized(exception) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
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
    # rubocop:enable Metrics/MethodLength

    # rubocop:todo Metrics/MethodLength
    def handle_error(exception) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return user_not_authorized(exception) if exception.is_a?(Pundit::NotAuthorizedError)
      raise exception if Rails.env.development?

      # call error reporting
      error_reporting(exception)

      respond_to do |format|
        format.turbo_stream do
          # rubocop:todo Layout/LineLength
          flash.now[:error] = exception.message # Set the exception message as an error flash message for the current request
          # rubocop:enable Layout/LineLength
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
    # rubocop:enable Metrics/MethodLength

    def error_reporting(exception); end

    # Extract language from request header
    def extract_locale_from_accept_language_header
      return unless request.env['HTTP_ACCEPT_LANGUAGE']

      lg = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first.to_sym
      lg.in?(I18n.available_locales) ? lg : nil
    end

    def set_locale
      locale = params[:locale] || # Request parameter
               session[:locale] || # Session stored locale
               current_person&.locale || # Model saved configuration
               extract_locale_from_accept_language_header || # Language header - browser config
               I18n.default_locale # Set in your config files, english by super-default

      I18n.locale = locale
      session[:locale] = locale # Store the locale in the session
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

    def after_sign_in_path_for(resource)
      stored_location_for(resource) ||
        if resource.permitted_to?('manage_platform')
          host_dashboard_path
        else
          BetterTogether.base_path_with_locale
        end
    end

    def after_sign_out_path_for(_resource_or_scope)
      BetterTogether.base_path_with_locale
    end

    # Configurable expiration time (e.g., 30 minutes)
    def platform_invitation_expiry_time
      30.minutes
    end

    helper_method :metric_viewable_type, :metric_viewable_id

    attr_accessor :metric_viewable

    def metric_viewable_type
      metric_viewable&.class&.name
    end

    def metric_viewable_id
      metric_viewable&.id
    end

    def determine_layout
      turbo_native_app? ? 'better_together/turbo_native' : 'better_together/application'
    end

    def turbo_native_app?
      request.user_agent.to_s.include?('Turbo Native')
    end
  end
end
