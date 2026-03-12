# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform, :skip_host_setup do
  it 'has a valid factory' do
    platform = build(:better_together_platform)
    expect(platform).to be_valid
  end

  describe 'Factory traits' do
    describe ':host' do
      subject(:host_platform) do
        described_class.find_by(host: true) || create(:better_together_platform, :host)
      end

      it 'creates a host platform' do
        expect(host_platform.host).to be true
        expect(host_platform.protected).to be true
      end
    end

    describe ':external' do
      subject(:external_platform) { create(:better_together_platform, :external) }

      it 'creates an external platform' do
        expect(external_platform.external).to be true
        expect(external_platform.host).to be false
      end
    end

    describe ':oauth_provider' do
      subject(:oauth_platform) { create(:better_together_platform, :oauth_provider) }

      it 'creates an OAuth provider platform' do
        expect(oauth_platform.external).to be true
        expect(oauth_platform.host).to be false
        expect(oauth_platform.name).to be_in(%w[GitHub Facebook Google Twitter])
        expect(oauth_platform.url).to be_present
      end
    end

    describe ':public' do
      subject(:public_platform) { create(:better_together_platform, :public) }

      it 'creates a public platform' do
        expect(public_platform.privacy).to eq('public')
      end
    end

    describe ':community_engine_peer' do
      subject(:community_engine_peer) { create(:better_together_platform, :community_engine_peer) }

      it 'creates an external CE-capable peer platform' do
        expect(community_engine_peer).to be_external_peer
        expect(community_engine_peer).to be_community_engine
        expect(community_engine_peer.federation_protocol).to eq('ce_oauth')
        expect(community_engine_peer.effective_oauth_issuer_url).to eq(community_engine_peer.host_url)
      end
    end
  end

  describe 'validations' do
    subject(:platform) { build(:better_together_platform, host_url:) }

    context 'with valid http url' do
      let(:host_url) { 'http://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with valid https url' do
      let(:host_url) { 'https://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with invalid scheme' do
      let(:host_url) { 'javascript:alert(1)' }

      it 'is invalid' do
        expect(platform).not_to be_valid
        expect(platform.errors[:host_url]).to be_present
      end
    end
  end

  describe 'platform domain synchronization' do
    it 'creates a primary platform domain for internal platforms from host_url' do
      platform = create(:better_together_platform, host_url: "https://primary-#{SecureRandom.hex(4)}.example.test")

      primary_domain = platform.reload.primary_platform_domain

      expect(primary_domain).to be_present
      expect(primary_domain.hostname).to eq(URI.parse(platform.host_url).host)
      expect(primary_domain).to be_primary
      expect(primary_domain).to be_active
    end

    it 'updates the primary platform domain hostname when host_url changes' do
      platform = create(:better_together_platform, host_url: "https://primary-#{SecureRandom.hex(4)}.example.test")
      new_host = "https://renamed-#{SecureRandom.hex(4)}.example.test"

      platform.update!(host_url: new_host)

      expect(platform.reload.primary_platform_domain.hostname).to eq(URI.parse(new_host).host)
    end

    it 'does not create a primary platform domain for external platforms' do
      platform = create(:better_together_platform, :external, host_url: "https://remote-#{SecureRandom.hex(4)}.example.test")

      expect(platform.reload.primary_platform_domain).to be_nil
    end
  end

  describe 'registry semantics' do
    it 'defaults local hosted platforms to community engine federation metadata' do
      platform = create(:better_together_platform, host_url: "https://registry-#{SecureRandom.hex(4)}.example.test")

      expect(platform).to be_local_hosted
      expect(platform).to be_community_engine
      expect(platform.network_visibility).to eq('private')
      expect(platform.connection_bootstrap_state).to eq('pending_host_request')
      expect(platform.federation_protocol).to eq('ce_oauth')
      expect(platform.effective_oauth_issuer_url).to eq(platform.resolved_host_url)
      expect(platform).to be_pending_host_connection_bootstrap
    end

    it 'defaults generic external peers to pending review without federation metadata' do
      platform = create(:better_together_platform, :external, host_url: "https://generic-#{SecureRandom.hex(4)}.example.test")

      expect(platform).to be_external_peer
      expect(platform).not_to be_community_engine
      expect(platform.network_visibility).to eq('private')
      expect(platform.connection_bootstrap_state).to eq('pending_review')
      expect(platform.federation_protocol).to be_blank
      expect(platform.effective_oauth_issuer_url).to be_nil
      expect(platform).not_to be_pending_host_connection_bootstrap
    end

    it 'allows external CE peers to advertise federation metadata explicitly' do
      platform = create(:better_together_platform, :community_engine_peer,
                        host_url: "https://peer-#{SecureRandom.hex(4)}.example.test")

      expect(platform).to be_external_peer
      expect(platform).to be_community_engine
      expect(platform.connection_bootstrap_state).to eq('pending_review')
      expect(platform.federation_protocol).to eq('ce_oauth')
      expect(platform.effective_oauth_issuer_url).to eq(platform.host_url)
    end

    it 'rejects invalid network visibility values' do
      platform = build(:better_together_platform, network_visibility: 'friends_only')

      expect(platform).not_to be_valid
      expect(platform.errors[:network_visibility]).to be_present
    end
  end

  describe '#connected_platforms' do
    it 'returns active incoming and outgoing connected peers' do
      platform = create(:better_together_platform)
      active_outgoing = create(:better_together_platform_connection, :active, source_platform: platform)
      active_incoming = create(:better_together_platform_connection, :active, target_platform: platform)
      create(:better_together_platform_connection, source_platform: platform)

      expect(platform.connected_platforms).to contain_exactly(
        active_outgoing.target_platform,
        active_incoming.source_platform
      )
    end
  end
end
