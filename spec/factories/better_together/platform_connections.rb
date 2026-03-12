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
    content_sharing_policy { 'none' }
    federation_auth_policy { 'none' }
    share_posts { false }
    share_pages { false }
    share_events { false }
    allow_identity_scope { false }
    allow_profile_read_scope { false }
    allow_content_read_scope { false }
    allow_content_write_scope { false }

    trait :active do
      status { 'active' }
    end

    trait :sharing_enabled do
      content_sharing_enabled { true }
      content_sharing_policy { 'mirror_network_feed' }
      share_posts { true }
    end

    trait :federated do
      federation_auth_enabled { true }
      federation_auth_policy { 'api_read' }
      allow_identity_scope { true }
      allow_content_read_scope { true }
    end

    trait :member_connection do
      connection_kind { 'member' }
    end
  end
end
