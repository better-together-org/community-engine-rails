# frozen_string_literal: true

module BetterTogether
  # OAuth client credential management for PlatformConnection.
  module PlatformConnectionOauthCredentials
    extend ActiveSupport::Concern

    def rotate_oauth_client_secret!
      update!(oauth_client_secret: generate_oauth_client_secret)
    end

    def oauth_client_secret
      self[:oauth_client_secret_ciphertext].to_s
    end

    def oauth_client_secret=(value)
      self[:oauth_client_secret_ciphertext] = value.to_s
    end

    private

    def ensure_oauth_client_credentials
      self.oauth_client_id = generate_oauth_client_id if oauth_client_id.blank?
      self.oauth_client_secret = generate_oauth_client_secret if oauth_client_secret.blank?
    end

    def generate_oauth_client_id
      "ce-#{SecureRandom.hex(12)}"
    end

    def generate_oauth_client_secret
      SecureRandom.hex(32)
    end
  end
end
