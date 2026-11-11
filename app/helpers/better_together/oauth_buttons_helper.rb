# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering OAuth provider sign-in buttons with proper branding
  module OauthButtonsHelper
    # Returns the appropriate Bootstrap button class for an OAuth provider
    # @param provider [Symbol, String] The OAuth provider name
    # @return [String] Bootstrap button classes
    def oauth_provider_button_class(provider) # rubocop:disable Metrics/MethodLength
      registered = BetterTogether::IdentityProviders.find(provider)&.button_class
      return registered if registered

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
    def oauth_provider_icon_class(provider) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      registered = BetterTogether::IdentityProviders.find(provider)&.icon_class
      return registered if registered

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

    # One sign-in button: `provider_id` is set for issuer-based providers (OpenID Connect), where each
    # configured issuer gets its own button; `provider_platform_id` identifies the issuer's identities.
    SignInChoice = Struct.new(:key, :label, :provider_id, :provider_platform_id, keyword_init: true)

    # The buttons to offer on this domain: one per configured provider, and one per configured issuer.
    def configured_sign_in_choices(resource_class)
      domain = BetterTogether::OmniauthFullHost.domain_for(request.env)
      resource_class.omniauth_providers.flat_map { |key| sign_in_choices_for(key, domain) }
    end

    # The label a signed-in person sees for a connected identity (the issuer name for OpenID Connect).
    def integration_provider_label(integration)
      return integration.provider.titleize unless BetterTogether::IdentityProviders.find(integration.provider)&.requires_issuer

      "#{BetterTogether::IdentityProviders.find(integration.provider).kind} (#{integration.platform&.name})"
    end

    def configured_omniauth_providers(resource_class)
      resource_class.omniauth_providers.select { |provider| oauth_provider_credentials_present?(provider) }
    end

    private

    def sign_in_choices_for(key, domain)
      provider = BetterTogether::IdentityProviders.find(key)
      return [] unless provider

      if provider.requires_issuer
        BetterTogether::IdentityProviderCredentials.choices(key, domain:).map do |row|
          SignInChoice.new(key:, label: row.display_name, provider_id: row.id, provider_platform_id: row.provider_platform_id)
        end
      elsif oauth_provider_credentials_present?(key)
        [SignInChoice.new(key:, label: OmniAuth::Utils.camelize(key))]
      else
        []
      end
    end

    def oauth_provider_credentials_present?(provider)
      return false unless BetterTogether::IdentityProviders.find(provider)

      BetterTogether::IdentityProviderCredentials.configured?(
        provider, domain: BetterTogether::OmniauthFullHost.domain_for(request.env)
      )
    end
  end
end
