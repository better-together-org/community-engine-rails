# frozen_string_literal: true

module BetterTogether
  # Per-platform sign-in configuration for one external provider Platform
  # (e.g. the external "github" Platform). `strategy` names the catalog entry.
  class PlatformIdentityProvider < ApplicationRecord
    encrypts :client_secret

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :provider_platform, class_name: '::BetterTogether::Platform'

    validates :strategy, presence: true,
                         inclusion: { in: ->(_) { BetterTogether::IdentityProviders.keys.map(&:to_s) } }
    validates :provider_platform_id, uniqueness: { scope: :platform_id }
    validate :provider_platform_is_external

    scope :enabled, -> { where(enabled: true) }

    private

    def provider_platform_is_external
      return if provider_platform.nil? || provider_platform.external?

      errors.add(:provider_platform, :invalid)
    end
  end
end
