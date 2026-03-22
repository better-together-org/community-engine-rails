# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/person_access_grant',
          class: 'BetterTogether::PersonAccessGrant',
          aliases: %i[better_together_person_access_grant person_access_grant] do
    person_link { association(:better_together_person_link, strategy: :create) }
    grantor_person { person_link.source_person }
    grantee_person { person_link.target_person }
    status { 'active' }
    accepted_at { Time.current }
    remote_grantee_identifier { grantee_person&.identifier }
    remote_grantee_name { grantee_person&.name }
    allow_profile_read { true }
    allow_private_posts { false }
    allow_private_pages { false }
    allow_private_events { false }
    allow_private_messages { false }

    trait :pending do
      status { 'pending' }
      accepted_at { nil }
    end
  end
end
