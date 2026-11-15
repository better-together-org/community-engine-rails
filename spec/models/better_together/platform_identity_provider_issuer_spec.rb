# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider, '#issuer' do
  let(:platform) { create(:better_together_platform) }

  before do
    allow(Resolv).to receive(:getaddresses).and_call_original
    allow(Resolv).to receive(:getaddresses).with('idp.example.org').and_return(['93.184.216.34'])
    allow(Resolv).to receive(:getaddresses).with('internal.example.org').and_return(['10.1.2.3'])
    allow(Resolv).to receive(:getaddresses).with('rebind.example.org').and_return(['93.184.216.34', '169.254.169.254'])
  end

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

  it 'rejects an issuer hostname that resolves to a private address' do
    expect(build_oidc('https://internal.example.org')).not_to be_valid
  end

  it 'rejects an issuer hostname with any link-local address' do
    expect(build_oidc('https://rebind.example.org')).not_to be_valid
  end

  it 'rejects an issuer hostname that does not resolve' do
    allow(Resolv).to receive(:getaddresses).with('nowhere.example.org').and_return([])
    expect(build_oidc('https://nowhere.example.org')).not_to be_valid
  end

  describe 'when the issuer DNS later becomes unsafe' do
    let!(:provider) { build_oidc('https://idp.example.org').tap { |row| row.assign_attributes(enabled: true) }.tap(&:save!) }

    before { allow(Resolv).to receive(:getaddresses).with('idp.example.org').and_return(['10.1.2.3']) }

    it 'can still be disabled' do
      expect(provider.update(enabled: false)).to be(true)
    end

    it 'cannot be enabled again while the DNS is unsafe' do
      provider.update!(enabled: false)

      expect(provider.update(enabled: true)).to be(false)
      expect(provider.errors).to include(:issuer)
    end

    it 'can still have unrelated fields changed without a new DNS check' do
      expect(provider.update(client_id: 'other')).to be(true)
    end
  end

  it 'does not require an issuer for other strategies' do
    github = create(:better_together_platform, external: true)

    expect(described_class.new(platform:, strategy: 'github', provider_platform: github,
                               client_id: 'a', client_secret: 'b')).to be_valid
  end
end
