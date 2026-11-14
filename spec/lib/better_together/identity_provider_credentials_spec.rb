# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviderCredentials do
  let!(:host_platform) { configure_host_platform }
  let(:host_domain) { ensure_host_platform_domain(host_platform) }
  let(:github_platform) { create(:better_together_platform, external: true) }
  let(:other_platform) { create(:better_together_platform) }
  let(:other_domain) do
    BetterTogether::PlatformDomain.create!(platform: other_platform, hostname: 'tenant.example.test', active: true)
  end
  let(:env) { { 'GITHUB_CLIENT_ID' => 'env-id', 'GITHUB_CLIENT_SECRET' => 'env-secret' } }

  def provider_row(platform:, domains:, **attrs)
    create(:better_together_platform_identity_provider, platform:, provider_platform: github_platform, **attrs)
      .tap { |row| row.update!(platform_domains: domains) }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    env.each { |k, v| allow(ENV).to receive(:fetch).with(k, nil).and_return(v) }
  end

  it 'uses ENV only for the host platform domains' do
    expect(described_class.resolve(:github, domain: host_domain).client_id).to eq('env-id')
  end

  it 'does not apply ENV to another platform domain' do
    expect(described_class.resolve(:github, domain: other_domain)).to be_nil
  end

  it 'returns nil when there is no domain' do
    expect(described_class.resolve(:github, domain: nil)).to be_nil
  end

  it 'uses the row that allows the domain, ahead of ENV' do
    provider_row(platform: host_platform, domains: [host_domain], client_id: 'row-id')

    expect(described_class.resolve(:github, domain: host_domain).client_id).to eq('row-id')
  end

  it 'lets a row on the host platform serve a hosted platform domain it allows' do
    provider_row(platform: host_platform, domains: [host_domain, other_domain], client_id: 'shared-id')

    expect(described_class.resolve(:github, domain: other_domain).client_id).to eq('shared-id')
  end

  it 'does not serve a domain the row does not list' do
    provider_row(platform: host_platform, domains: [host_domain], client_id: 'host-only')

    expect(described_class.resolve(:github, domain: other_domain)).to be_nil
  end

  it 'does not fall back to ENV when a disabled row claims the domain' do
    provider_row(platform: host_platform, domains: [host_domain], enabled: false, client_id: 'row-id')

    expect(described_class.resolve(:github, domain: host_domain)).to be_nil
  end

  it 'reports configured only when credentials resolve' do
    expect([described_class.configured?(:github, domain: host_domain),
            described_class.configured?(:github, domain: other_domain)]).to eq([true, false])
  end
end
