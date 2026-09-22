# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering OAuth provider sign-in buttons with proper branding
  module OauthButtonsHelper
    OAUTH_PROVIDER_ENV_VARS = {
      github: %w[GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET]
    }.freeze

    # Returns the appropriate Bootstrap button class for an OAuth provider
    # @param provider [Symbol, String] The OAuth provider name
    # @return [String] Bootstrap button classes
    def oauth_provider_button_class(provider) # rubocop:disable Metrics/MethodLength
      case provider.to_s.downcase
      when 'github', 'twitter', 'x'
        'btn btn-dark'
      when 'google', 'google_oauth2'
        'btn btn-outline-danger'
      when 'facebook', 'linkedin'
        'btn btn-primary'
      when 'microsoft', 'microsoft_office365'
        'btn btn-info'
      else
        'btn btn-secondary'
      end
    end

    # Returns the Font Awesome icon class for an OAuth provider
    # @param provider [Symbol, String] The OAuth provider name
    # @return [String] Font Awesome icon classes
    def oauth_provider_icon_class(provider) # rubocop:disable Metrics/MethodLength
      case provider.to_s.downcase
      when 'github'
        'fa-brands fa-github'
      when 'google', 'google_oauth2'
        'fa-brands fa-google'
      when 'facebook'
        'fa-brands fa-facebook'
      when 'twitter', 'x'
        'fa-brands fa-x-twitter'
      when 'linkedin'
        'fa-brands fa-linkedin'
      when 'microsoft', 'microsoft_office365'
        'fa-brands fa-microsoft'
      else
        'fa-solid fa-plug'
      end
    end

    def configured_omniauth_providers(resource_class)
      resource_class.omniauth_providers.select { |provider| oauth_provider_credentials_present?(provider) }
    end

    private

    def oauth_provider_credentials_present?(provider)
      required_env_vars = OAUTH_PROVIDER_ENV_VARS.fetch(provider.to_sym, [])
      required_env_vars.all? { |env_var| ENV.fetch(env_var, nil).present? }
    end
  end
end
