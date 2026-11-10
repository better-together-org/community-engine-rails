# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviderCredentials do
  let!(:host_platform) { configure_host_platform }
  let(:github_platform) { create(:better_together_platform, external: true) }
  let(:env) { { 'GITHUB_CLIENT_ID' => 'env-id', 'GITHUB_CLIENT_SECRET' => 'env-secret' } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    env.each { |k, v| allow(ENV).to receive(:fetch).with(k, nil).and_return(v) }
  end

  it 'falls back to ENV when no row exists' do
    expect(described_class.resolve(:github, platform: host_platform).client_id).to eq('env-id')
  end

  it 'prefers the host platform row over ENV' do
    create(:better_together_platform_identity_provider, platform: host_platform,
                                                        provider_platform: github_platform, client_id: 'row-id')

    expect(described_class.resolve(:github, platform: nil).client_id).to eq('row-id')
  end

  it 'prefers the platform row over the host row' do
    other = create(:better_together_platform)
    create(:better_together_platform_identity_provider, platform: host_platform,
                                                        provider_platform: github_platform, client_id: 'host-id')
    create(:better_together_platform_identity_provider, platform: other,
                                                        provider_platform: github_platform, client_id: 'own-id')

    expect(described_class.resolve(:github, platform: other).client_id).to eq('own-id')
  end

  it 'ignores disabled rows' do
    create(:better_together_platform_identity_provider, platform: host_platform, enabled: false,
                                                        provider_platform: github_platform, client_id: 'row-id')

    expect(described_class.resolve(:github, platform: host_platform).client_id).to eq('env-id')
  end
end
