# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/platform_connection',
          class: 'BetterTogether::PlatformConnection',
          aliases: %i[better_together_platform_connection platform_connection] do
    association :source_platform, factory: :better_together_platform
    association :target_platform, factory: :better_together_platform
    status { 'pending' }
    connection_kind { 'peer' }
    content_sharing_enabled { false }
    federation_auth_enabled { false }

    trait :active do
      status { 'active' }
    end

    trait :sharing_enabled do
      content_sharing_enabled { true }
    end

    trait :federated do
      federation_auth_enabled { true }
    end

    trait :member_connection do
      connection_kind { 'member' }
    end
  end
end
