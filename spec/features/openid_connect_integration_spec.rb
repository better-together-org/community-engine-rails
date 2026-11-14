# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OpenID Connect sign-in', :no_auth, :omniauth, :skip_host_setup do
  let!(:platform) { configure_host_platform }
  let(:domain) { ensure_host_platform_domain(platform) }
  let(:oauth_email) { unique_email }
  let(:oauth_uid) { unique_oauth_uid }
  let(:email_verified) { true }
  let(:oidc_auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'openid_connect', uid: oauth_uid,
      info: { email: oauth_email, email_verified:, name: 'OIDC Person', nickname: unique_username },
      credentials: { token: 'oidc_token_123', expires_at: 1.hour.from_now.to_i }
    )
  end

  before do
    platform.update!(requires_invitation: false, privacy: 'public')
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:openid_connect] = oidc_auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:openid_connect] = nil
  end

  def configure_oidc(domains:, enabled: true, trust: true, issuer: 'https://idp.example.org')
    create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect', enabled:,
                                                        provider_platform: nil, issuer:, trust_verified_email: trust)
      .tap { |row| row.update!(platform_domains: domains) }
  end

  it 'refuses sign-in when no configuration allows the domain', :aggregate_failures do
    domain

    expect { visit '/users/auth/openid_connect/callback' }.not_to change(BetterTogether.user_class, :count)
    expect(page).to have_current_path(%r{/users/sign-in})
  end

  it 'signs in on a domain the configuration allows, linking the identity to this platform', :aggregate_failures do
    configure_oidc(domains: [domain])
    visit '/users/auth/openid_connect/callback'

    user = BetterTogether.user_class.find_by(email: oauth_email)
    expect(user).to be_confirmed
    expect(user.person_platform_integrations.first.local_platform).to eq(platform)
  end

  it 'does not trust an issuer email that the configuration has not opted into', :aggregate_failures do
    configure_oidc(domains: [domain], trust: false)
    existing = create(:user, :confirmed, email: oauth_email)
    visit '/users/auth/openid_connect/callback'

    expect(existing.reload.person_platform_integrations).to be_empty
  end

  context 'when the provider does not assert a verified email' do
    let(:email_verified) { false }

    it 'does not link to an existing account' do
      configure_oidc(domains: [domain])
      create(:user, :confirmed, email: oauth_email)
      visit '/users/auth/openid_connect/callback'

      expect(BetterTogether::PersonPlatformIntegration.where(provider: 'openid_connect', uid: oauth_uid)).to be_empty
    end
  end
end
