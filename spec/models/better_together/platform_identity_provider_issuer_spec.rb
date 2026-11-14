# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider, '#issuer' do
  let(:platform) { create(:better_together_platform) }

  def build_oidc(issuer)
    described_class.new(platform:, strategy: 'openid_connect', client_id: 'cid', client_secret: 'sec', issuer:)
  end

  it 'is valid with a public https issuer and creates the generic provider platform', :aggregate_failures do
    row = build_oidc('https://idp.example.org')

    expect(row).to be_valid
    expect(row.provider_platform).to be_external
  end

  it 'requires an issuer' do
    expect(build_oidc(nil)).not_to be_valid
  end

  it 'rejects a non-https issuer' do
    expect(build_oidc('http://idp.example.org')).not_to be_valid
  end

  it 'rejects an issuer on a private address' do
    expect(build_oidc('https://10.0.0.5')).not_to be_valid
  end

  it 'does not require an issuer for other strategies' do
    github = create(:better_together_platform, external: true)

    expect(described_class.new(platform:, strategy: 'github', provider_platform: github,
                               client_id: 'a', client_secret: 'b')).to be_valid
  end
end
