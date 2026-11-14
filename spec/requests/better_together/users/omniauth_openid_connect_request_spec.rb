# frozen_string_literal: true

require 'rails_helper'

# Request phase against a stubbed discovery document: the redirect carries the per-platform client,
# PKCE and a callback URL on the requested platform domain.
RSpec.describe 'OpenID Connect request phase', :no_auth do
  let(:platform) { configure_host_platform }
  let(:issuer) { 'https://idp.example.org' }
  let(:discovery) do
    { issuer:, authorization_endpoint: "#{issuer}/authorize", token_endpoint: "#{issuer}/token",
      userinfo_endpoint: "#{issuer}/userinfo", jwks_uri: "#{issuer}/jwks",
      response_types_supported: ['code'], subject_types_supported: ['public'],
      id_token_signing_alg_values_supported: ['RS256'] }
  end

  before do
    OmniAuth.config.test_mode = false
    domain = ensure_host_platform_domain(platform)
    create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect',
                                                        provider_platform: nil, issuer:, client_id: 'oidc-client')
      .update!(platform_domains: [domain])
    stub_request(:get, "#{issuer}/.well-known/openid-configuration")
      .to_return(status: 200, body: discovery.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'redirects to the issuer with the platform client id, PKCE and this domain callback', :aggregate_failures do
    post '/users/auth/openid_connect'
    query = Rack::Utils.parse_query(URI.parse(response.location).query)

    expect(response.location).to start_with("#{issuer}/authorize")
    expect(query).to include('client_id' => 'oidc-client', 'code_challenge_method' => 'S256')
    expect(query['redirect_uri']).to end_with('/users/auth/openid_connect/callback')
  end
end
