# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::LinkedSeedIngestService do
  describe '#call' do
    let(:connection) do
      create(
        :better_together_platform_connection,
        :active,
        source_platform: create(:better_together_platform),
        target_platform: create(:better_together_platform),
        federation_auth_policy: 'api_read',
        allow_content_read_scope: true,
        allow_linked_content_read_scope: true
      )
    end
    let(:grant) do
      create(
        :better_together_person_access_grant,
        person_link: create(
          :better_together_person_link,
          platform_connection: connection,
          source_person: create(:better_together_person),
          target_person: create(:better_together_person)
        ),
        allow_private_posts: true
      )
    end
    let(:seed_data) do
      record = create(:better_together_post, creator: grant.grantor_person, privacy: 'private', platform: connection.source_platform)

      BetterTogether::Seeds::FederatedSeedBuilder.call(
        record:,
        connection:,
        lane: 'private_linked',
        origin_metadata: {
          person_access_grant_id: grant.id,
          recipient_identifier: grant.grantee_person.identifier,
          required_scope: 'private_posts'
        }
      )
    end

    it 'imports private linked seeds into the recipient-scoped cache' do
      result = described_class.call(
        connection:,
        recipient_person: grant.grantee_person,
        seeds: [seed_data]
      )

      expect(result.processed_count).to eq(1)
      expect(result.linked_seeds.length).to eq(1)
      expect(result.linked_seeds.first.recipient_person).to eq(grant.grantee_person)
      expect(result.linked_seeds.first.payload_data['type']).to eq('post')
    end

    it 'skips seeds that are not allowed by the grant scope' do
      disallowed_seed = seed_data.deep_stringify_keys
      disallowed_seed['better_together']['seed']['origin']['required_scope'] = 'private_messages'

      result = described_class.call(
        connection:,
        recipient_person: grant.grantee_person,
        seeds: [disallowed_seed]
      )

      expect(result.processed_count).to eq(0)
      expect(result.unsupported_seeds.length).to eq(1)
    end
  end
end
