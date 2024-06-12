# frozen_string_literal: true

module BetterTogether
  class PersonPlatformIntegration < ApplicationRecord
    PROVIDERS = {
      facebook: 'Facebook',
      github: 'Github',
      google_oauth2: 'Google',
      linkedin: 'Linkedin'
    }.freeze

    belongs_to :person
    belongs_to :platform
    belongs_to :user

    Devise.omniauth_configs.each_key do |provider|
      scope provider, -> { where(provider:) }
    end

    def expired?
      expires_at? && expires_at <= Time.zone.now
    end

    def token
      renew_token! if expired?
      access_token
    end

    def renew_token!
      new_token = current_token.refresh!
      update(
        access_token: new_token.token,
        refresh_token: new_token.refresh_token,
        expires_at: Time.at(new_token.expires_at)
      )
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
        ENV.fetch("#{provider.downcase}_client_id", nil),
        ENV.fetch("#{provider.downcase}_client_secret", nil)
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

      attributes[:profile_url] = auth.info.urls.first.last unless person_platform_integration.persisted?

      attributes
    end

    def self.update_or_initialize(person_platform_integration, auth)
      if person_platform_integration.present?
        person_platform_integration.update(attributes_from_omniauth(auth))
      else
        person_platform_integration = new(
          attributes_from_omniauth(auth)
        )
      end

      person_platform_integration
    end
  end
end
