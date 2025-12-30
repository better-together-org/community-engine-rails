# frozen_string_literal: true

module BetterTogether
  class PersonPlatformIntegration < ApplicationRecord
    PROVIDERS = {
      facebook: 'Facebook',
      github: 'Github',
      google_oauth2: 'Google',
      linkedin: 'Linkedin'
    }.freeze

    # Encrypt sensitive OAuth credentials at rest
    encrypts :access_token
    encrypts :access_token_secret
    encrypts :refresh_token

    belongs_to :person
    belongs_to :platform
    belongs_to :user

    validates :provider, presence: true, inclusion: {
      in: PROVIDERS.keys.map(&:to_s)
    }
    validates :uid, presence: true, uniqueness: {
      scope: :provider
    }
    validates :user, presence: true
    validates :access_token, presence: { on: :create }

    Devise.omniauth_configs.each_key do |provider|
      scope provider, -> { where(provider:) }
    end

    def expired?
      expires_at? && expires_at <= Time.zone.now
    end

    def token
      renew_token! if expired? && supports_refresh?
      access_token
    end

    def supports_refresh?
      refresh_token.present? && expires_at.present?
    end

    def renew_token!
      return false unless supports_refresh?

      new_token = current_token.refresh!
      update(
        access_token: new_token.token,
        refresh_token: new_token.refresh_token,
        expires_at: Time.at(new_token.expires_at)
      )
    rescue OAuth2::Error => e
      Rails.logger.error "Token refresh failed for #{provider} (#{id}): #{e.message}"
      false
    end

    def refresh_auth_hash
      renew_token! if expired?

      omniauth = strategy
      omniauth.access_token = current_token

      update(self.class.attributes_from_omniauth(omniauth.auth_hash))
    end

    def current_token
      OAuth2::AccessToken.new(
        strategy.client,
        access_token,
        refresh_token:
      )
    end

    # return an OmniAuth::Strategies instance for the provider
    def strategy
      OmniAuth::Strategies.const_get(OmniAuth::Utils.camelize(provider)).new(
        nil,
        ENV.fetch("#{provider.upcase}_CLIENT_ID", nil),
        ENV.fetch("#{provider.upcase}_CLIENT_SECRET", nil)
      )
    end

    def self.attributes_from_omniauth(auth)
      expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil

      attributes = {
        provider: auth.provider,
        uid: auth.uid,
        expires_at:,
        access_token: auth.credentials.token,
        access_token_secret: auth.credentials.secret,
        auth: auth.to_hash
      }

      attributes[:handle] = auth.info.nickname if auth.info.nickname.present?
      attributes[:name] = auth.info.name if auth.info.name.present?
      attributes[:image_url] = URI.parse(auth.info.image) if auth.info.image.present?

      # Set profile_url from the auth hash if available
      if auth.extra&.raw_info&.html_url.present?
        attributes[:profile_url] = auth.extra.raw_info.html_url
      elsif auth.info&.urls.present? && auth.info.urls.is_a?(Hash)
        attributes[:profile_url] = auth.info.urls.values.first
      end

      attributes
    end

    def self.update_or_initialize(person_platform_integration, auth, platform: nil)
      attributes = attributes_from_omniauth(auth)

      # Find the external OAuth platform based on the provider
      external_platform = find_external_platform_for_provider(auth.provider)
      attributes[:platform] = external_platform if external_platform.present?

      # Allow manual platform override (for backward compatibility)
      attributes[:platform] = platform if platform.present?

      if person_platform_integration.present?
        person_platform_integration.update(attributes)
      else
        person_platform_integration = new(attributes)
      end

      person_platform_integration
    end

    private_class_method def self.find_external_platform_for_provider(provider)
      # Map OAuth provider names to platform identifiers
      provider_mapping = {
        'github' => 'github',
        'google_oauth2' => 'google',
        'facebook' => 'facebook',
        'linkedin' => 'linkedin',
        'twitter' => 'twitter'
      }

      platform_identifier = provider_mapping[provider.to_s]
      return nil unless platform_identifier

      Platform.external.find_by(identifier: platform_identifier)
    end
  end
end
