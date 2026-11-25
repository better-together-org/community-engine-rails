# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Facebook OAuth Integration', :no_auth, :omniauth, :skip_host_setup do
  let!(:platform) { configure_host_platform }
  let(:oauth_email) { unique_email }
  let(:oauth_uid) { unique_oauth_uid }
  let(:info) { { email: oauth_email, name: 'Facebook Person', nickname: unique_username } }
  let(:facebook_auth_hash) do
    OmniAuth::AuthHash.new(provider: 'facebook', uid: oauth_uid, info:,
                           credentials: { token: 'fb_token_123', expires_at: 1.hour.from_now.to_i })
  end

  before do
    platform.update!(requires_invitation: false, privacy: 'public')
    ensure_host_platform_domain(platform)
    stub_provider_env('FACEBOOK_CLIENT_ID', 'FACEBOOK_CLIENT_SECRET')
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:facebook] = facebook_auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:facebook] = nil
  end

  it 'ships Facebook with its env vars and scope', :aggregate_failures do
    facebook = BetterTogether::IdentityProviders.fetch(:facebook)

    expect(facebook.env_vars).to eq(%w[FACEBOOK_CLIENT_ID FACEBOOK_CLIENT_SECRET])
    expect(facebook.scope).to eq('email,public_profile')
  end

  it 'never treats a Facebook email as verified' do
    expect(BetterTogether::IdentityProviders.fetch(:facebook).verified_email?(facebook_auth_hash)).to be(false)
  end

  context 'with a new person' do
    it 'creates an unconfirmed account, sends no session and stores no identity', :aggregate_failures do
      visit '/users/auth/facebook/callback'

      user = BetterTogether.user_class.find_by(email: oauth_email)
      expect(user).to be_present
      expect(user).not_to be_confirmed
      expect(BetterTogether::PersonPlatformIntegration.where(provider: 'facebook', uid: oauth_uid)).to be_empty
      expect(page).to have_current_path(%r{/users/sign-in})
    end
  end

  context 'with an email that already has an account' do
    it 'never links the Facebook identity to it', :aggregate_failures do
      create(:user, :confirmed, email: oauth_email)

      expect { visit '/users/auth/facebook/callback' }.not_to change(BetterTogether::PersonPlatformIntegration, :count)
      expect(page).to have_current_path(%r{/users/sign-(in|up)})
    end
  end

  context 'when Facebook returns no email' do
    let(:info) { { name: 'No Email Person', nickname: unique_username } }

    it 'creates nothing and explains why', :aggregate_failures do
      expect { visit '/users/auth/facebook/callback' }.not_to change(BetterTogether.user_class, :count)
      expect(page).to have_content('Facebook')
    end
  end

  context 'when Facebook is not configured for the requested domain' do
    it 'refuses sign-in and creates nothing' do
      allow(ENV).to receive(:fetch).with('FACEBOOK_CLIENT_ID', nil).and_return(nil)

      expect { visit '/users/auth/facebook/callback' }.not_to change(BetterTogether.user_class, :count)
    end
  end
end
