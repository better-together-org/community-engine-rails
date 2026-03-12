# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BetterTogether::FederatedContentPullService do
  describe '#call' do
    let(:source_platform) { create(:better_together_platform, :community_engine_peer, url: 'https://peer.example.test') }
    let(:target_platform) { create(:better_together_platform) }
    let(:connection) do
      create(
        :better_together_platform_connection,
        :active,
        source_platform:,
        target_platform:,
        federation_auth_policy: 'api_read',
        content_sharing_policy: 'mirror_network_feed',
        share_posts: true,
        allow_identity_scope: true,
        allow_content_read_scope: true
      )
    end

    it 'pulls one batch from the remote federation feed' do
      stub_request(:get, 'https://peer.example.test/en/federation/content_feed?limit=50')
        .with(headers: { 'Authorization' => "Bearer #{connection.federation_access_token}" })
        .to_return(
          status: 200,
          body: {
            items: [{ type: 'post', id: SecureRandom.uuid, attributes: { title: 'Remote Post', content: 'Body' } }],
            next_cursor: 'cursor-2'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.call(connection:)

      expect(result.items.length).to eq(1)
      expect(result.next_cursor).to eq('cursor-2')
    end

    it 'raises on non-success responses' do
      stub_request(:get, 'https://peer.example.test/en/federation/content_feed?limit=50')
        .to_return(status: 403, body: 'forbidden')

      expect do
        described_class.call(connection:)
      end.to raise_error(/403/)
    end
  end
end
