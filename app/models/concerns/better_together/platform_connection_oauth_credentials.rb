# frozen_string_literal: true

module BetterTogether
  # OAuth client credential management for PlatformConnection.
  #
  # The client secret is stored encrypted at rest via ActiveRecord::Encryption.
  # The plaintext is transparently available on read for outbound requests (pull services).
  # Inbound verification uses constant-time comparison of the decrypted value.
  module PlatformConnectionOauthCredentials
    extend ActiveSupport::Concern

    included do
      encrypts :oauth_client_secret
    end

    # Verify a provided secret against the stored encrypted value in constant time.
    def authenticate_oauth_secret(candidate)
      return false if oauth_client_secret.blank? || candidate.blank?

      ActiveSupport::SecurityUtils.secure_compare(oauth_client_secret.to_s, candidate.to_s)
    end

    # Rotate the client secret.  Returns self.
    def rotate_oauth_client_secret!
      update!(oauth_client_secret: generate_oauth_client_secret)
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
