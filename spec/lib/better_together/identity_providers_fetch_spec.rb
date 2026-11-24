# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviders, '.fetch' do
  let(:oidc) { described_class.fetch(:openid_connect) }
  let(:auth_for) do
    lambda do |info: {}, raw: {}|
      OmniAuth::AuthHash.new(info: { email: 'a@example.test' }.merge(info), extra: { raw_info: raw })
    end
  end

  it 'requires an issuer and has no ENV credentials', :aggregate_failures do
    expect(oidc.requires_issuer).to be(true)
    expect(oidc.env_vars).to be_empty
  end

  it 'accepts email_verified from info or raw_info', :aggregate_failures do
    expect(oidc.verified_email?(auth_for.call(info: { email_verified: true }))).to be(true)
    expect(oidc.verified_email?(auth_for.call(raw: { email_verified: true }))).to be(true)
  end

  it 'rejects false, missing, or email-less assertions', :aggregate_failures do
    expect(oidc.verified_email?(auth_for.call(info: { email_verified: false }))).to be(false)
    expect(oidc.verified_email?(auth_for.call)).to be(false)
    expect(oidc.verified_email?(OmniAuth::AuthHash.new(info: { email_verified: true }))).to be(false)
  end

  it 'configures discovery, PKCE and a redirect URI on the requested host', :aggregate_failures do
    creds = BetterTogether::IdentityProviderCredentials::Result.new(
      client_id: 'cid', client_secret: 'sec', scope: 'openid', options: { 'issuer' => 'https://idp.example.test' }
    )
    allow(BetterTogether::OmniauthFullHost).to receive(:call).and_return('https://tenant.example.test')
    options = {}
    oidc.configure_options(options, creds, {})

    expect(options).to include(issuer: 'https://idp.example.test', discovery: true, pkce: true)
    expect(options[:client_options]).to include(identifier: 'cid', redirect_uri: 'https://tenant.example.test/users/auth/openid_connect/callback')
  end
end
