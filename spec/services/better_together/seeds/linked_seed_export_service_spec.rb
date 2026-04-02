# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::LinkedSeedExportService do
  describe '#call' do
    let(:source_platform) { create(:better_together_platform) }
    let(:target_platform) { create(:better_together_platform) }
    let(:connection) do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
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

    before do
      create(:better_together_post, creator: grant.grantor_person, privacy: 'private', platform: source_platform)
      create(:better_together_post, creator: grant.grantor_person, privacy: 'public', platform: source_platform)
      create(:better_together_post, creator: create(:better_together_person), privacy: 'private', platform: source_platform)
    end

    it 'exports only grantor-authored private content allowed by the grant' do
      result = described_class.call(connection:, recipient_identifier: grant.grantee_person.identifier)

      expect(result.person_access_grant).to eq(grant)
      expect(result.seeds.length).to eq(1)
      seed = result.seeds.first.with_indifferent_access.fetch(BetterTogether::Seed::DEFAULT_ROOT_KEY).with_indifferent_access
      expect(seed.dig('seed', 'origin', 'lane')).to eq('private_linked')
      expect(seed.dig('seed', 'origin', 'person_access_grant_id')).to eq(grant.id)
      expect(seed.dig('payload', 'type')).to eq('post')
    end

    it 'returns no seeds when there is no active matching grant' do
      result = described_class.call(connection:, recipient_identifier: 'missing-recipient')

      expect(result.person_access_grant).to be_nil
      expect(result.seeds).to eq([])
    end

    it 'continues pagination beyond 500 offset records' do
      create_list(
        :better_together_post,
        504,
        creator: grant.grantor_person,
        privacy: 'private',
        platform: source_platform
      )

      result = described_class.call(
        connection:,
        recipient_identifier: grant.grantee_person.identifier,
        cursor: '500',
        limit: 10
      )

      expect(result.seeds.length).to eq(5)
      expect(result.next_cursor).to be_nil
    end
  end
end
