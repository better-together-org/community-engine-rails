# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviderCredentials, '.resolve' do
  let!(:platform) { configure_host_platform }
  let(:domain) { ensure_host_platform_domain(platform) }
  let(:other_platform) { create(:better_together_platform) }
  let(:other_domain) do
    BetterTogether::PlatformDomain.create!(platform: other_platform, hostname: 'tenant.example.test', active: true)
  end
  let!(:one) { oidc('https://idp.one.example.org', domains: [domain], client_id: 'one-id') }
  let!(:two) { oidc('https://idp.two.example.org', domains: [domain], client_id: 'two-id') }

  def oidc(issuer, domains:, **attrs)
    create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect',
                                                        provider_platform: nil, issuer:, **attrs)
      .tap { |row| row.update!(platform_domains: domains) }
  end

  it 'refuses to guess when several issuers serve the domain and none was chosen' do
    expect(described_class.resolve(:openid_connect, domain:)).to be_nil
  end

  it 'resolves the issuer the person chose', :aggregate_failures do
    creds = described_class.resolve(:openid_connect, domain:, provider_id: two.id)

    expect(creds.client_id).to eq('two-id')
    expect(creds.identity_platform).to eq(two.provider_platform)
  end

  it 'does not resolve a chosen issuer that does not serve the domain' do
    expect(described_class.resolve(:openid_connect, domain: other_domain, provider_id: two.id)).to be_nil
  end

  it 'does not resolve a disabled issuer' do
    two.update!(enabled: false)

    expect(described_class.resolve(:openid_connect, domain:, provider_id: two.id)).to be_nil
  end

  it 'resolves the only configured issuer without a choice' do
    two.update!(enabled: false)
    one.update!(platform_domains: [domain])
    two.update!(platform_domains: [])

    expect(described_class.resolve(:openid_connect, domain:).client_id).to eq('one-id')
  end

  it 'lists the enabled issuers for the sign-in buttons' do
    two.update!(enabled: false)

    expect(described_class.choices(:openid_connect, domain:)).to eq([one])
  end

  it 'does not pass the display options on to the strategy' do
    one.update!(label: 'Co-op', trust_verified_email: 'true')

    expect(described_class.resolve(:openid_connect, domain:, provider_id: one.id).options.keys)
      .not_to include('label', 'trust_verified_email')
  end
end
