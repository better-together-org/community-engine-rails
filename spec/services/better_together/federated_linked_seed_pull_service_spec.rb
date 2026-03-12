# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BetterTogether::FederatedLinkedSeedPullService do
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
        allow_content_read_scope: true,
        allow_linked_content_read_scope: true
      )
    end

    it 'pulls a linked-private seed batch for a recipient' do
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: {
            access_token: 'oauth-linked-token',
            token_type: 'Bearer',
            expires_in: 900,
            scope: 'linked_content.read'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "#{peer_host}/en/federation/linked_seeds?limit=50&recipient_identifier=recipient-123")
        .with(headers: { 'Authorization' => 'Bearer oauth-linked-token' })
        .to_return(
          status: 200,
          body: {
            seeds: [{ 'better_together' => { 'seed' => { 'origin' => { 'lane' => 'private_linked' } },
                                             'payload' => { 'type' => 'post', 'id' => SecureRandom.uuid } } }], next_cursor: 'linked-2'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.call(connection:, recipient_identifier: 'recipient-123')

      expect(result.seeds.length).to eq(1)
      expect(result.next_cursor).to eq('linked-2')
    end
  end
end
