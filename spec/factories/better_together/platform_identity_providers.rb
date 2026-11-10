# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/platform_identity_provider',
          class: 'BetterTogether::PlatformIdentityProvider',
          aliases: %i[better_together_platform_identity_provider platform_identity_provider] do
    association :platform, factory: :'better_together/platform'
    association :provider_platform, factory: :'better_together/platform', external: true
    strategy { 'github' }
    client_id { "id-#{SecureRandom.hex(4)}" }
    client_secret { "secret-#{SecureRandom.hex(8)}" }
    enabled { true }
  end
end
