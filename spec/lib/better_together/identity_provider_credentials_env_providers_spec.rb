# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviderCredentials, '.env_providers' do
  let!(:host_platform) { configure_host_platform }
  let(:host_domain) { ensure_host_platform_domain(host_platform) }

  before { stub_provider_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET') }

  it 'lists env-configured providers with the host domains they serve', :aggregate_failures do
    host_domain
    result = described_class.env_providers(host_platform).find { |e| e.provider.key == :github }

    expect(result.domains).to eq([host_domain])
  end

  it 'omits providers whose env vars are not set' do
    host_domain

    expect(described_class.env_providers(host_platform).map { |e| e.provider.key }).not_to include(:google_oauth2)
  end

  it 'drops domains a provider row claims' do
    row = create(:better_together_platform_identity_provider, platform: host_platform,
                                                              provider_platform: create(:better_together_platform, external: true))
    row.update!(platform_domains: [host_domain])

    expect(described_class.env_providers(host_platform).find { |e| e.provider.key == :github }.domains).to be_empty
  end

  it 'returns nothing for a non-host platform' do
    expect(described_class.env_providers(create(:better_together_platform))).to eq([])
  end
end
