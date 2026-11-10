# frozen_string_literal: true

module BetterTogether
  # One platform domain (callback host) a sign-in provider configuration is allowed to serve.
  # A domain may be allowed by only one configuration per strategy, so resolution is never ambiguous.
  class PlatformIdentityProviderDomain < ApplicationRecord
    belongs_to :platform_identity_provider, class_name: '::BetterTogether::PlatformIdentityProvider',
                                            inverse_of: :provider_domains
    belongs_to :platform_domain, class_name: '::BetterTogether::PlatformDomain'

    validates :platform_domain_id, uniqueness: { scope: :platform_identity_provider_id }
    validate :domain_not_claimed_by_another_configuration

    private

    def domain_not_claimed_by_another_configuration
      return if platform_identity_provider.blank? || platform_domain_id.blank?

      errors.add(:platform_domain, :taken) if claimed_elsewhere?
    end

    def claimed_elsewhere?
      others = PlatformIdentityProvider.where(strategy: platform_identity_provider.strategy)
                                       .where.not(id: platform_identity_provider.id)
      self.class.where(platform_domain_id:, platform_identity_provider_id: others.select(:id)).exists?
    end
  end
end
