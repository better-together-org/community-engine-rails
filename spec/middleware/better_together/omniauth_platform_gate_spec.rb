# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OmniauthPlatformGate, :no_auth, :omniauth, :skip_host_setup, type: :request do
  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:other_hostname) { 'tenant.example.test' }
  let!(:other_domain) do
    BetterTogether::PlatformDomain.create!(platform: other_platform, hostname: other_hostname, active: true)
  end

  before do
    host_platform.update!(requires_invitation: false)
    other_platform.update!(requires_invitation: false)
    ensure_host_platform_domain(host_platform)
    stub_provider_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET')
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = github_oauth_hash(email: unique_email, uid: unique_oauth_uid,
                                                           nickname: unique_username, name: "Gate Person #{SecureRandom.hex(4)}")
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  it 'refuses the callback on a domain the provider is not configured for', :aggregate_failures do
    host! other_hostname
    get '/users/auth/github/callback'

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include('/users/sign-in')
    expect(BetterTogether::PersonPlatformIntegration.where(provider: 'github')).to be_empty
  end

  it 'refuses the request phase on a domain the provider is not configured for' do
    host! other_hostname
    post '/users/auth/github'

    expect(response.location).to include('/users/sign-in')
  end

  it 'does not fall back to the host platform configuration' do
    host! other_hostname

    expect { get '/users/auth/github/callback' }.not_to change(BetterTogether.user_class, :count)
  end

  it 'lets the callback through on a domain the provider allows' do
    provider = create(:better_together_platform_identity_provider, platform: host_platform,
                                                                   provider_platform: create(:better_together_platform, external: true))
    provider.update!(platform_domains: [other_domain])
    host! other_hostname

    get '/users/auth/github/callback'
    expect(BetterTogether::PersonPlatformIntegration.count).to eq(1)
  end

  it 'ignores paths that are not provider routes' do
    host! other_hostname
    get '/en/users/sign-in'

    expect(response).to have_http_status(:ok)
  end
end
