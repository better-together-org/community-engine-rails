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

  def login(email, password) # rubocop:todo Metrics/MethodLength
    # Clear any existing session state to prevent interference between tests
    reset_session if respond_to?(:reset_session)

    # Ensure we have a valid locale for the route
    locale = (I18n.locale || I18n.default_locale).to_s

    begin
      post better_together.user_session_path(locale: locale), params: {
        user: { email: email, password: password }
      }
    rescue ActionController::RoutingError => e
      # Fallback: try with explicit engine route if the helper fails
      Rails.logger.warn "Route helper failed: #{e.message}. Using fallback route."
      post "/#{locale}/users/sign-in", params: {
        user: { email: email, password: password }
      }
    end
  end

  def configure_host_platform
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
