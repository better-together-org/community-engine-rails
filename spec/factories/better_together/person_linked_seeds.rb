# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/person_linked_seed',
          class: 'BetterTogether::PersonLinkedSeed',
          aliases: %i[better_together_person_linked_seed person_linked_seed] do
    person_access_grant { association(:better_together_person_access_grant, strategy: :create) }
    recipient_person { person_access_grant.grantee_person }
    source_platform { person_access_grant.person_link.platform_connection.source_platform }
    identifier { "linked-seed-#{SecureRandom.hex(6)}" }
    source_record_type { 'BetterTogether::Post' }
    source_record_id { SecureRandom.uuid }
    seed_type { 'post' }
    version { '1.0.0' }
    payload { JSON.generate('title' => 'Private linked seed', 'body' => 'Encrypted body') }
    source_updated_at { 1.hour.ago }
    last_synced_at { Time.current }
    metadata { { 'lane' => 'person_linked_private' } }
  end
end
