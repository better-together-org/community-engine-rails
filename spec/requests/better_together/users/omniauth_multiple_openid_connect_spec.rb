# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Several OpenID Connect issuers on one platform', :no_auth, :omniauth, :skip_host_setup do
  let!(:platform) { configure_host_platform }
  let(:domain) { ensure_host_platform_domain(platform) }
  let(:shared_sub) { unique_oauth_uid }
  let!(:one) { oidc('https://idp.one.example.org', trust_verified_email: true) }
  let!(:two) { oidc('https://idp.two.example.org', trust_verified_email: true) }

  def oidc(issuer, **attrs)
    create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect',
                                                        provider_platform: nil, issuer:, **attrs)
      .tap { |row| row.update!(platform_domains: [domain]) }
  end

  def mock_identity(email:, uid: shared_sub)
    OmniAuth.config.mock_auth[:openid_connect] = OmniAuth::AuthHash.new(
      provider: 'openid_connect', uid:,
      info: { email:, email_verified: true, name: 'OIDC Person', nickname: unique_username },
      credentials: { token: 'oidc_token', expires_at: 1.hour.from_now.to_i }
    )
  end

  def sign_in_through(row)
    post '/users/auth/openid_connect', params: { provider_id: row.id }
    follow_redirect! while response.redirect? && response.location.include?('/users/auth/openid_connect')
  end

  before do
    platform.update!(requires_invitation: false, privacy: 'public')
    domain
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:openid_connect] = nil
  end

  it 'refuses a request that does not say which issuer to use' do
    post '/users/auth/openid_connect'

    expect(response.location).to include('/users/sign-in')
  end

  it 'refuses a callback that does not follow a request for an issuer' do
    mock_identity(email: unique_email)

    expect { get '/users/auth/openid_connect/callback' }.not_to change(BetterTogether.user_class, :count)
  end

  it 'refuses an issuer id that does not belong to this platform domain' do
    post '/users/auth/openid_connect', params: { provider_id: SecureRandom.uuid }

    expect(response.location).to include('/users/sign-in')
  end

  it 'keeps the same sub from two issuers as separate identities, connecting both', :aggregate_failures do
    mock_identity(email: unique_email)
    sign_in_through(one)
    mock_identity(email: unique_email)
    sign_in_through(two)

    identities = BetterTogether::PersonPlatformIntegration.where(provider: 'openid_connect', uid: shared_sub)
    expect(identities.map(&:platform_id)).to contain_exactly(one.provider_platform_id, two.provider_platform_id)
    expect(identities.map(&:user_id).uniq.size).to eq(1) # the second issuer connects to the signed-in person
  end

  it 'does not link an existing account when the issuer is not trusted', :aggregate_failures do
    one.update!(trust_verified_email: false)
    existing = create(:user, :confirmed, email: unique_email)
    mock_identity(email: existing.email)
    sign_in_through(one)

    expect(existing.reload.person_platform_integrations).to be_empty
  end
end
