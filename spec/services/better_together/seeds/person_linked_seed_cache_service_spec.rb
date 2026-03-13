# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::PersonLinkedSeedCacheService do
  it 'caches a recipient-scoped private seed for an active grant' do
    grant = create(:better_together_person_access_grant)

    result = described_class.call(
      person_access_grant: grant,
      recipient_person: grant.grantee_person,
      source_platform: grant.person_link.platform_connection.source_platform,
      identifier: 'private-seed-1',
      seed_type: 'post',
      payload: { 'title' => 'Private Post' },
      source_record_type: 'BetterTogether::Post',
      source_record_id: SecureRandom.uuid,
      version: '1.0.0',
      metadata: { 'lane' => 'person_linked_private' }
    )

    expect(result.created).to be(true)
    expect(result.linked_seed.recipient_person).to eq(grant.grantee_person)
    expect(result.linked_seed.payload_data).to eq('title' => 'Private Post')
  end

  it 'rejects caching when the grant recipient does not match' do
    grant = create(:better_together_person_access_grant)

    expect do
      described_class.call(
        person_access_grant: grant,
        recipient_person: create(:better_together_person),
        source_platform: grant.person_link.platform_connection.source_platform,
        identifier: 'private-seed-2',
        seed_type: 'post',
        payload: { 'title' => 'Private Post' },
        source_record_type: 'BetterTogether::Post',
        source_record_id: SecureRandom.uuid,
        version: '1.0.0'
      )
    end.to raise_error(ArgumentError, 'recipient must match grant grantee')
  end
end
