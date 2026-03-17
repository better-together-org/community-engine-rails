# frozen_string_literal: true

module BetterTogether
  # OAuth client credential management for PlatformConnection.
  #
  # Two-layer secret storage:
  #   1. `oauth_client_secret` — AR::Encryption (AES-256-GCM), transparent plaintext on read.
  #      Used by outbound pull services that must present the secret to a remote platform.
  #   2. `oauth_client_secret_digest` — BCrypt one-way hash.
  #      Used for inbound verification so the hot authentication path never decrypts.
  #
  # Both fields are kept in sync on create and rotation.  If the digest column does not
  # yet exist (e.g. in a test database before the migration runs), `authenticate_oauth_secret`
  # falls back to the SHA-256 constant-time path for backward compatibility.
  module PlatformConnectionOauthCredentials
    extend ActiveSupport::Concern

    included do
      encrypts :oauth_client_secret
      before_validation :ensure_oauth_client_credentials
    end

    # Verify a candidate secret using the BCrypt digest (preferred) or SHA-256 fallback.
    # BCrypt comparison is inherently timing-safe and avoids decrypting the AR-encrypted
    # column on every inbound request.
    def authenticate_oauth_secret(candidate)
      return false if candidate.blank?

      if oauth_client_secret_digest.present?
        BCrypt::Password.new(oauth_client_secret_digest) == candidate.to_s
      else
        # Fallback: constant-time SHA-256 comparison when digest not yet stored
        # (occurs before migration or on legacy records not yet rotated).
        return false if oauth_client_secret.blank?

        stored   = Digest::SHA256.hexdigest(oauth_client_secret.to_s)
        provided = Digest::SHA256.hexdigest(candidate.to_s)
        ActiveSupport::SecurityUtils.secure_compare(stored, provided)
      end
    end

    # Rotate the client secret.  Regenerates both the AR-encrypted value (outbound) and
    # the BCrypt digest (inbound).  Clears the outbound token cache so the next pull
    # immediately exchanges new credentials with the remote platform.
    # Returns self.
    def rotate_oauth_client_secret!
      raw = generate_oauth_client_secret
      update!(
        oauth_client_secret: raw,
        oauth_client_secret_digest: BCrypt::Password.create(raw)
      )
      Rails.cache.delete("bt:fed_token:#{oauth_client_id}")
      self
    end

    private

    def ensure_oauth_client_credentials
      self.oauth_client_id = generate_oauth_client_id if oauth_client_id.blank?

      return if oauth_client_secret.present?

      raw = generate_oauth_client_secret
      self.oauth_client_secret = raw
      self.oauth_client_secret_digest = BCrypt::Password.create(raw)
    end

    def generate_oauth_client_id
      "ce-#{SecureRandom.hex(12)}"
    end

    def generate_oauth_client_secret
      SecureRandom.hex(32)
    end
  end
end
