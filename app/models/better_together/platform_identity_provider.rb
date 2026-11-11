# frozen_string_literal: true

module BetterTogether
  # Per-platform sign-in configuration for one external provider Platform
  # (e.g. the external "github" Platform). `strategy` names the catalog entry.
  class PlatformIdentityProvider < ApplicationRecord
    encrypts :client_secret

    # Keep the secret out of #inspect, error reports and serialization (encrypts already filters inspect).
    self.filter_attributes += %i[client_secret]

    normalizes :client_id, :client_secret, with: ->(value) { value.to_s.strip.presence }

    validates :client_id, :client_secret,
              format: { without: /[[:cntrl:]\s]/, message: :invalid_characters }, allow_nil: true

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :provider_platform, class_name: '::BetterTogether::Platform'

    # Domains (callback hosts) this configuration may serve; sign-in is refused anywhere else.
    has_many :provider_domains, class_name: '::BetterTogether::PlatformIdentityProviderDomain',
                                dependent: :destroy, inverse_of: :platform_identity_provider
    has_many :platform_domains, through: :provider_domains, class_name: '::BetterTogether::PlatformDomain'

    validates :strategy, presence: true,
                         inclusion: { in: ->(_) { BetterTogether::IdentityProviders.keys.map(&:to_s) } }
    validates :provider_platform_id, uniqueness: { scope: :platform_id }
    validate :provider_platform_is_external

    before_validation :assign_provider_platform, if: -> { provider_platform.nil? }

    scope :enabled, -> { where(enabled: true) }

    def serializable_hash(options = nil)
      super(options.to_h.merge(except: Array(options.to_h[:except]) + %w[client_secret]))
    end

    def catalog_entry
      BetterTogether::IdentityProviders.find(strategy)
    end

    private

    # The external Platform that represents this provider (seeded by ExternalPlatformBuilder).
    def assign_provider_platform
      identifier = catalog_entry&.platform_identifier
      return if identifier.blank?

      self.provider_platform = Platform.find_by(identifier:, external: true)
    end

    def provider_platform_is_external
      return if provider_platform.nil? || provider_platform.external?

      errors.add(:provider_platform, :invalid)
    end
  end
end
