# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BetterTogether::Federation::Transport::HttpAdapter do
  describe '.accessible?' do
    let(:peer_host) { 'https://example.com' }
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
        allow_content_read_scope: true
      )
    end

    it 'returns true when the remote host accepts TCP connections' do
      socket = instance_double(BasicSocket, closed?: false, close: nil)
      allow(Socket).to receive(:tcp).and_yield(socket)

      expect(described_class.accessible?(connection:)).to be(true)
      expect(Socket).to have_received(:tcp).twice
    end

    it 'returns false when the remote host cannot be reached' do
      allow(Socket).to receive(:tcp).and_raise(Errno::ECONNREFUSED)

      expect(described_class.accessible?(connection:)).to be(false)
    end

    it 'returns false (not an uncaught exception) when Socket.tcp raises IO::TimeoutError' do
      allow(Socket).to receive(:tcp).and_raise(IO::TimeoutError)

      expect(described_class.accessible?(connection:)).to be(false)
    end
  end

  describe '.call' do
    # Test env defaults to :null_store outside prspec's per-worker MemoryStore reassignment.
    # The 401-retry examples need a real cache to exercise invalidate-and-refetch behaviour.
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    let(:peer_host) { 'https://example.com' }
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
            seeds: [{ better_together: { payload: { type: 'post', id: SecureRandom.uuid,
                                                    attributes: { title: 'Remote Post', content: 'Body' } } } }],
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

    it 'raises when oauth token exchange is unavailable' do
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(status: 401, body: { error: 'invalid_client' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect do
        described_class.call(connection:)
      end.to raise_error(/content feed token request failed for connection #{connection.id}/)
    end

    it 'invalidates a stale cached token and retries once on a 401 feed response' do
      cache_key = "bt:fed_token:#{connection.oauth_client_id}"
      Rails.cache.write(cache_key, 'stale-token', expires_in: 900.seconds)

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => 'Bearer stale-token' })
        .to_return(status: 401, body: { error: 'invalid_token' }.to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: { access_token: 'fresh-token', token_type: 'Bearer', expires_in: 900,
                  scope: 'content.feed.read' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => 'Bearer fresh-token' })
        .to_return(
          status: 200,
          body: { seeds: [], next_cursor: nil }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = described_class.call(connection:)

      expect(result.seeds).to eq([])
      expect(Rails.cache.read(cache_key)).to eq('fresh-token')
    end

    it 'raises with connection context when the retried request also returns 401' do
      cache_key = "bt:fed_token:#{connection.oauth_client_id}"
      Rails.cache.write(cache_key, 'stale-token', expires_in: 900.seconds)

      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .to_return(status: 401, body: { error: 'invalid_token' }.to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: { access_token: 'still-bad-token', token_type: 'Bearer', expires_in: 900,
                  scope: 'content.feed.read' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        described_class.call(connection:)
      end.to raise_error(/federation feed request failed with 401 for connection #{connection.id}/)
    end
  end

  describe 'remote platform resolution' do
    # Regression coverage for a bug where every URL was built from source_platform
    # unconditionally, so a connection where the LOCAL platform happens to be
    # source_platform (rather than target_platform) would fetch from itself instead
    # of the actual federated peer. Every existing example above already exercises
    # the "peer is source_platform" shape; these prove the reverse shape now works
    # too, for both a host: true local platform and an ordinary non-host one —
    # i.e. resolution is based on the external flag, not host: true.
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    let(:peer_host) { 'https://example.com' }
    let(:remote_platform) do
      create(:better_together_platform, :community_engine_peer, host_url: peer_host, oauth_issuer_url: peer_host)
    end

    # rails_helper seeds exactly one host: true platform for the whole suite (Platform
    # enforces a single host record) — reuse it rather than creating a second one.
    it 'fetches from the remote peer when the local HOST platform is source_platform' do
      local_host_platform = BetterTogether::Platform.find_by(host: true)
      connection = create(
        :better_together_platform_connection, :active,
        source_platform: local_host_platform,
        target_platform: remote_platform,
        federation_auth_policy: 'api_read',
        content_sharing_policy: 'mirror_network_feed',
        allow_content_read_scope: true
      )
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: { access_token: 'oauth-access-token', token_type: 'Bearer', expires_in: 900,
                  scope: 'content.feed.read' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => 'Bearer oauth-access-token' })
        .to_return(
          status: 200,
          body: { seeds: [], next_cursor: nil }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # WebMock raises NetConnectNotAllowedError on any unstubbed request, so if the
      # bug regressed (source_platform's own host_url used instead) this fails loudly
      # rather than silently fetching the wrong thing.
      expect { described_class.call(connection:) }.not_to raise_error
    end

    it 'fetches from the remote peer when a non-host local platform is source_platform' do
      non_host_local_platform = create(:better_together_platform) # external: false, host: false by default
      connection = create(
        :better_together_platform_connection, :active,
        source_platform: non_host_local_platform,
        target_platform: remote_platform,
        federation_auth_policy: 'api_read',
        content_sharing_policy: 'mirror_network_feed',
        allow_content_read_scope: true
      )
      stub_request(:post, "#{peer_host}/en/federation/oauth/token")
        .to_return(
          status: 200,
          body: { access_token: 'oauth-access-token', token_type: 'Bearer', expires_in: 900,
                  scope: 'content.feed.read' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, "#{peer_host}/en/federation/content_feed?limit=50")
        .with(headers: { 'Authorization' => 'Bearer oauth-access-token' })
        .to_return(
          status: 200,
          body: { seeds: [], next_cursor: nil }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect { described_class.call(connection:) }.not_to raise_error
    end
  end

  describe 'SSRF exception normalization' do
    let(:peer_host) { 'https://example.com' }
    let(:source_platform) do
      create(:better_together_platform, :community_engine_peer, host_url: peer_host, oauth_issuer_url: peer_host)
    end
    let(:target_platform) { create(:better_together_platform) }
    let(:connection) do
      create(
        :better_together_platform_connection, :active,
        source_platform:, target_platform:,
        federation_auth_policy: 'api_read',
        content_sharing_policy: 'mirror_network_feed',
        allow_content_read_scope: true
      )
    end

    it 'converts SsrfFilter::PrivateIPAddress to SSRFError' do
      allow(SsrfFilter).to receive(:post).and_raise(SsrfFilter::PrivateIPAddress)

      expect { described_class.call(connection:) }.to raise_error(described_class::SSRFError)
    end

    it 'converts SsrfFilter::TooManyRedirects to SSRFError' do
      allow(SsrfFilter).to receive(:post).and_raise(SsrfFilter::TooManyRedirects)

      expect { described_class.call(connection:) }.to raise_error(described_class::SSRFError)
    end

    it 'converts SsrfFilter::UnresolvedHostname to SSRFError' do
      allow(SsrfFilter).to receive(:post).and_raise(SsrfFilter::UnresolvedHostname)

      expect { described_class.call(connection:) }.to raise_error(described_class::SSRFError)
    end
  end
end
