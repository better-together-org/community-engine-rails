# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BetterTogether::FederatedContentPullService do
  describe '#call' do
    let(:peer_host) { "https://peer-#{SecureRandom.hex(4)}.example.test" }
    let(:source_platform) { create(:better_together_platform, :community_engine_peer, host_url: peer_host, oauth_issuer_url: peer_host) }
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
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .with(
          body: {
            grant_type: 'client_credentials',
            client_id: connection.oauth_client_id,
            client_secret: connection.oauth_client_secret,
            scope: 'content.feed.read'
          }
        )
        .to_return(
          status: 200,
          body: {
            access_token: 'oauth-access-token',
            token_type: 'Bearer',
            expires_in: 900,
            scope: 'content.feed.read'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => 'Bearer oauth-access-token' })
        .to_return(
          status: 200,
          body: {
            seeds: [{ better_together: { payload: { type: 'post', id: SecureRandom.uuid, attributes: { title: 'Remote Post', content: 'Body' } } } }],
            next_cursor: 'cursor-2'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.call(connection:)

      expect(result.seeds.length).to eq(1)
      expect(result.next_cursor).to eq('cursor-2')
    end

    it 'raises on non-success responses' do
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: {
            access_token: 'oauth-access-token',
            token_type: 'Bearer',
            expires_in: 900,
            scope: 'content.feed.read'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .to_return(status: 403, body: 'forbidden')

      expect do
        described_class.call(connection:)
      end.to raise_error(/403/)
    end

    it 'falls back to the legacy connection token when oauth token exchange is unavailable' do
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(status: 401, body: { error: 'invalid_client' }.to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => "Bearer #{connection.federation_access_token}" })
        .to_return(
          status: 200,
          body: { seeds: [], next_cursor: nil }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.call(connection:)

      expect(result.seeds).to eq([])
    end
  end
end
