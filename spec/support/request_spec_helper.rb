# frozen_string_literal: true

# Common route helpers included in request specs.
module RequestSpecHelper # :nodoc:
  include Rails.application.routes.url_helpers
  include Rails.application.routes.mounted_helpers
  include BetterTogether::Engine.routes.url_helpers

  # Ensure route helpers use default locale
  def default_url_options
    { locale: I18n.default_locale }
  end

  def json
    JSON.parse(response.body)
  end

  # rubocop:todo Metrics/AbcSize
  # rubocop:todo Metrics/PerceivedComplexity
  # rubocop:todo Metrics/CyclomaticComplexity
  # rubocop:todo Lint/CopDirectiveSyntax
  def login(email, password) # rubocop:todo Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # rubocop:enable Lint/CopDirectiveSyntax
    # Clear any existing session state to prevent interference between tests
    reset_session if respond_to?(:reset_session)

    # Ensure we have a valid locale for the route
    locale = (I18n.locale || I18n.default_locale).to_s

    # Verify user exists and is confirmed before attempting login
    user = BetterTogether::User.find_by(email: email)
    unless user&.confirmed?
      raise "Cannot login as #{email} - user does not exist or is not confirmed"
    end

    post "/#{locale}/users/sign-in", params: {
      user: { email: email, password: password }
    }
    # Ensure session cookie is stored by following Devise redirect in request specs
    follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?

    # Verify login was successful
    return if response.status == 200 || session[:warden_user_key]

    raise "Login failed for #{email}. Response status: #{response.status}"
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/AbcSize

  # rubocop:todo Metrics/AbcSize
  # rubocop:todo Metrics/MethodLength
  # rubocop:todo Metrics/CyclomaticComplexity
  # rubocop:todo Metrics/PerceivedComplexity
  def logout
    # Clear session data completely
    if respond_to?(:reset_session)
      # For request specs
      reset_session
    end

    # Clear any Warden authentication data
    @request&.env&.delete('warden') if respond_to?(:request) && defined?(@request)

    # Only issue an HTTP sign-out request in request specs. Controller/feature specs
    # should rely on session + Warden cleanup above to avoid route-helper flake.
    return unless respond_to?(:delete) && !respond_to?(:controller) && !respond_to?(:visit)

    # Ensure we have a valid locale for the route
    locale = (I18n.locale || I18n.default_locale).to_s

    begin
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

  # NOTE: configure_host_platform method is provided by AutomaticTestConfiguration
  # which is included globally. Do not duplicate it here to avoid method conflicts.
end
