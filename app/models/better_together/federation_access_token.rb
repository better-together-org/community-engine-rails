# frozen_string_literal: true

require 'digest'

# Manages BetterTogether operations.
module BetterTogether
  # Represents a scoped access token for federated platform connections.
  class FederationAccessToken < ApplicationRecord
    belongs_to :platform_connection, class_name: '::BetterTogether::PlatformConnection'
    attr_accessor :token

    validates :token_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true

    before_validation :ensure_token_values, on: :create

    scope :active, lambda {
      joins(:platform_connection)
        .where(revoked_at: nil)
        .where(arel_table[:expires_at].gt(Time.current))
        .where(better_together_platform_connections: { status: 'active' })
    }

    def self.find_active_by_plaintext(value)
      return if value.blank?

      active.find_by(token_digest: digest(value))
    end

    def self.digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def scope_list
      scopes.to_s.split(/\s+/).map(&:strip).reject(&:blank?).uniq
    end

    def includes_scope?(scope)
      scope_list.include?(scope.to_s)
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    def touch_last_used!
      return if last_used_at.present? && last_used_at > 1.minute.ago

      update_column(:last_used_at, Time.current)
    end

    private

    def ensure_token_values
      self.token = SecureRandom.hex(32) if token.blank?
      self.token_digest = self.class.digest(token) if token_digest.blank? && token.present?
    end
  end
end
