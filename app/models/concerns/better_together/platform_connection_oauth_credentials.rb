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
    # SHA256 digests are compared (not raw values) so secure_compare always receives
    # equal-length strings, avoiding the ArgumentError it raises on length mismatch.
    def authenticate_oauth_secret(candidate)
      return false if oauth_client_secret.blank? || candidate.blank?

      stored   = Digest::SHA256.hexdigest(oauth_client_secret.to_s)
      provided = Digest::SHA256.hexdigest(candidate.to_s)
      ActiveSupport::SecurityUtils.secure_compare(stored, provided)
    end

    # Rotate the client secret.  Clears the outbound token cache so the next
    # pull immediately exchanges new credentials with the remote platform.
    # Returns self.
    def rotate_oauth_client_secret!
      update!(oauth_client_secret: generate_oauth_client_secret)
      Rails.cache.delete("bt:fed_token:#{oauth_client_id}")
      self
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
