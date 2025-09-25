# frozen_string_literal: true

module RequestSpecHelper
  include Rails.application.routes.url_helpers
  include BetterTogether::Engine.routes.url_helpers

  # Ensure route helpers use default locale
  def default_url_options
    { locale: I18n.default_locale }
  end

  def json
    JSON.parse(response.body)
  end

  # rubocop:todo Metrics/AbcSize
  def login(email, password) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
    # Clear any existing session state to prevent interference between tests
    reset_session if respond_to?(:reset_session)

    # Ensure we have a valid locale for the route
    locale = (I18n.locale || I18n.default_locale).to_s

    begin
      post better_together.user_session_path(locale: locale), params: {
        user: { email: email, password: password }
      }
      # Ensure session cookie is stored by following Devise redirect in request specs
      follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?
    rescue ActionController::RoutingError => e
      # Fallback: try with explicit engine route if the helper fails
      Rails.logger.warn "Route helper failed: #{e.message}. Using fallback route."
      post "/#{locale}/users/sign-in", params: {
        user: { email: email, password: password }
      }
    end
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:todo Metrics/AbcSize
  # rubocop:todo Metrics/MethodLength
  # rubocop:todo Metrics/CyclomaticComplexity
  # rubocop:todo Metrics/PerceivedComplexity
  def logout
    # Clear session data completely
    if respond_to?(:reset_session!)
      # For feature specs (Capybara)
      reset_session!
    elsif respond_to?(:reset_session)
      # For request specs
      reset_session
    end

    # Clear any Warden authentication data
    @request&.env&.delete('warden') if respond_to?(:request) && defined?(@request)

    # Ensure we have a valid locale for the route
    locale = (I18n.locale || I18n.default_locale).to_s

    begin
      delete better_together.destroy_user_session_path(locale: locale)
    rescue ActionController::RoutingError => e
      # Fallback: try with explicit engine route if the helper fails
      Rails.logger.warn "Route helper failed for logout: #{e.message}. Using fallback route."
      delete "/#{locale}/users/sign-out"
    rescue StandardError => e
      # Ignore errors during logout as session may already be clean
      Rails.logger.debug "Logout failed (may be expected): #{e.message}"
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def configure_host_platform # rubocop:disable Metrics/MethodLength
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public')
    else
      host_platform = create(:better_together_platform, :host, privacy: 'public')
    end

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')

    unless platform_manager
      create(
        :user, :confirmed, :platform_manager,
        email: 'manager@example.test',
        password: 'password12345'
      )
    end

    host_platform
  end
end
