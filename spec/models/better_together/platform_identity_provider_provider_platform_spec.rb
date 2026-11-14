# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider, '#provider_platform' do
  let!(:platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }

  def oidc(issuer, on: platform, **attrs)
    build(:better_together_platform_identity_provider, platform: on, strategy: 'openid_connect',
                                                       provider_platform: nil, issuer:, **attrs)
  end

  it 'allows different issuers on one platform, each with its own external platform', :aggregate_failures do
    first = oidc('https://idp.one.example.org').tap(&:save!)
    second = oidc('https://idp.two.example.org').tap(&:save!)

    expect(second).to be_persisted
    expect(first.provider_platform).not_to eq(second.provider_platform)
    expect(first.provider_platform).to be_external
  end

  it 'rejects the same issuer twice on a platform, however it is spelled', :aggregate_failures do
    oidc('https://idp.example.org').save!

    expect(oidc('https://IDP.example.org/')).not_to be_valid
    expect(oidc('https://idp.example.org')).not_to be_valid
  end

  it 'stores the issuer in one canonical form' do
    row = oidc('https://IDP.Example.org/realm/').tap(&:save!)

    expect(row.issuer).to eq('https://idp.example.org/realm')
  end

  it 'lets another platform configure the same issuer' do
    oidc('https://idp.example.org').save!

    expect(oidc('https://idp.example.org', on: other_platform)).to be_valid
  end

  it 'does not allow the issuer to change after creation' do
    row = oidc('https://idp.example.org').tap(&:save!)
    row.issuer = 'https://idp.other.example.org'

    expect(row).not_to be_valid
  end

  it 'lets one domain serve several issuers but not the same issuer twice', :aggregate_failures do
    domain = ensure_host_platform_domain(platform)
    one = oidc('https://idp.one.example.org').tap(&:save!)
    two = oidc('https://idp.two.example.org').tap(&:save!)
    same_issuer_elsewhere = oidc('https://idp.one.example.org', on: other_platform).tap(&:save!)
    BetterTogether::PlatformIdentityProviderDomain.create!(platform_identity_provider: one, platform_domain: domain)

    expect(BetterTogether::PlatformIdentityProviderDomain.new(platform_identity_provider: two,
                                                              platform_domain: domain)).to be_valid
    expect(BetterTogether::PlatformIdentityProviderDomain.new(platform_identity_provider: same_issuer_elsewhere,
                                                              platform_domain: domain)).not_to be_valid
  end

  it 'does not trust verified emails unless the configuration opts in', :aggregate_failures do
    expect(oidc('https://idp.example.org')).not_to be_trust_verified_email
    expect(oidc('https://idp.example.org', trust_verified_email: 'true')).to be_trust_verified_email
  end

  it 'names the sign-in button from the label, else the issuer host', :aggregate_failures do
    expect(oidc('https://idp.example.org').display_name).to eq('idp.example.org')
    expect(oidc('https://idp.example.org', label: 'Co-op login').display_name).to eq('Co-op login')
  end
end
