# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google OAuth Integration', :no_auth, :omniauth, :skip_host_setup do
  let!(:platform) { configure_host_platform }
  let(:oauth_email) { unique_email }
  let(:oauth_uid) { unique_oauth_uid }
  let(:email_verified) { true }
  let(:google_auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'google_oauth2', uid: oauth_uid,
      info: { email: oauth_email, email_verified:, name: 'Google Person', nickname: unique_username },
      credentials: { token: 'google_token_123', expires_at: 1.hour.from_now.to_i }
    )
  end

  before do
    platform.update!(requires_invitation: false, privacy: 'public')
    ensure_host_platform_domain(platform)
    stub_provider_env('GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET')
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = google_auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  context 'with a verified Google email and no existing account' do
    it 'creates a confirmed user and links the Google identity to this platform', :aggregate_failures do
      visit '/users/auth/google_oauth2/callback'

      user = BetterTogether.user_class.find_by(email: oauth_email)
      expect(user).to be_confirmed
      integration = user.person_platform_integrations.first
      expect([integration.provider, integration.uid, integration.local_platform]).to eq(['google_oauth2', oauth_uid, platform])
    end
  end

  context 'with an unverified Google email' do
    let(:email_verified) { false }

    it 'does not link to an existing account', :aggregate_failures do
      create(:user, :confirmed, email: oauth_email)
      visit '/users/auth/google_oauth2/callback'

      expect(BetterTogether::PersonPlatformIntegration.where(provider: 'google_oauth2', uid: oauth_uid)).to be_empty
    end
  end

  context 'when Google is not configured for the requested domain' do
    it 'refuses sign-in and creates nothing', :aggregate_failures do
      allow(ENV).to receive(:fetch).with('GOOGLE_CLIENT_ID', nil).and_return(nil)

      expect { visit '/users/auth/google_oauth2/callback' }.not_to change(BetterTogether.user_class, :count)
      expect(page).to have_current_path(%r{/users/sign-in})
    end
  end
end
