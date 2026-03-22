# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/platform_domain',
          class: 'BetterTogether::PlatformDomain',
          aliases: %i[better_together_platform_domain platform_domain] do
    association :platform, factory: :'better_together/platform'
    hostname { "platform-#{SecureRandom.hex(6)}.test" }
    primary { false }
    active { true }

    trait :primary do
      primary { true }
    end
  end
end
