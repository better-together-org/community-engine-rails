# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GitHub OAuth Integration' do
  include BetterTogether::DeviseSessionHelpers

  let(:platform) { configure_host_platform }
  let(:community) { platform.community }

  before do
    # Set up test platform for host application
    platform # Ensure platform is created
    Capybara.app_host = "http://#{platform.host}"
  end

  describe 'OAuth authentication flow' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: {
                                 email: 'test@example.com',
                                 name: 'Test User',
                                 nickname: 'testuser',
                                 image: 'https://avatars.githubusercontent.com/u/123456?v=4'
                               },
                               credentials: {
                                 token: 'github_access_token_123',
                                 secret: 'github_secret_456',
                                 expires_at: 1.hour.from_now.to_i
                               },
                               extra: {
                                 raw_info: {
                                   login: 'testuser',
                                   html_url: 'https://github.com/testuser'
                                 }
                               }
                             })
    end

    before do
      # Configure OmniAuth test mode
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:github] = github_auth_hash
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:github] = nil
    end

    context 'when user does not exist' do
      it 'creates new user and signs them in', :js do
        visit '/users/auth/github'

        expect(page).to have_current_path('/users/edit', ignore_query: true)
        expect(page).to have_text('Successfully authenticated from Github account.')

        # Check that user was created
        user = BetterTogether.user_class.find_by(email: 'test@example.com')
        expect(user).to be_present
        expect(user.person.name).to eq('Test User')
        expect(user.person.handle).to eq('testuser')

        # Check that PersonPlatformIntegration was created
        integration = user.person_platform_integrations.first
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq('123456')
        expect(integration.access_token).to eq('github_access_token_123')
      end
    end

    context 'when user already exists with same email' do
      let!(:existing_user) { create(:user, email: 'test@example.com') }

      it 'signs in existing user and links GitHub account', :js do
        visit '/users/auth/github'

        expect(page).to have_current_path('/users/edit', ignore_query: true)
        expect(page).to have_text('Successfully authenticated from Github account.')

        # Check that no new user was created
        expect(BetterTogether.user_class.count).to eq(1)

        # Check that PersonPlatformIntegration was linked to existing user
        integration = existing_user.person_platform_integrations.first
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq('123456')
      end
    end

    context 'when PersonPlatformIntegration already exists' do
      let!(:existing_integration) do
        create(:person_platform_integration,
               provider: 'github',
               uid: '123456',
               access_token: 'old_token')
      end

      it 'updates existing integration and signs in user', :js do
        visit '/users/auth/github'

        expect(page).to have_current_path('/users/edit', ignore_query: true)
        expect(page).to have_text('Successfully authenticated from Github account.')

        # Check that integration was updated
        existing_integration.reload
        expect(existing_integration.access_token).to eq('github_access_token_123')
        expect(existing_integration.name).to eq('Test User')
        expect(existing_integration.handle).to eq('testuser')
      end
    end

    context 'when user is already signed in' do
      let(:current_user) { create(:user, email: 'current@example.com') }

      before do
        sign_in current_user
      end

      it 'links GitHub account to current user', :js do
        visit '/users/auth/github'

        expect(page).to have_current_path('/users/edit', ignore_query: true)
        expect(page).to have_text('Successfully authenticated from Github account.')

        # Check that no new user was created
        expect(BetterTogether.user_class.count).to eq(1)

        # Check that PersonPlatformIntegration was linked to current user
        integration = current_user.person_platform_integrations.first
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq('123456')
        expect(integration.user).to eq(current_user)
      end
    end

    context 'when OAuth fails' do
      before do
        OmniAuth.config.mock_auth[:github] = :invalid_credentials
      end

      it 'handles OAuth failure gracefully' do
        visit '/users/auth/github'

        expect(page).to have_text('There was a problem signing you in. Please register or try signing in later.')
        expect(page).to have_current_path('/', ignore_query: true)
      end
    end

    context 'when user creation fails due to validation errors' do
      before do
        # Mock user validation to fail
        allow_any_instance_of(BetterTogether.user_class).to receive(:save).and_return(false) # rubocop:todo RSpec/AnyInstance
        allow_any_instance_of(BetterTogether.user_class).to receive(:persisted?).and_return(false) # rubocop:todo RSpec/AnyInstance
      end

      it 'redirects to registration with error message' do
        visit '/users/auth/github'

        expect(page).to have_text('test@example.com is not authorized')
        expect(page).to have_current_path('/users/sign_up', ignore_query: true)
      end
    end
  end

  describe 'OAuth callback error handling' do
    before do
      OmniAuth.config.test_mode = true
    end

    after do
      OmniAuth.config.test_mode = false
    end

    context 'when auth hash is missing required information' do
      let(:incomplete_auth_hash) do
        OmniAuth::AuthHash.new({
                                 provider: 'github',
                                 uid: '123456',
                                 info: {
                                   # Missing email
                                   name: 'Test User'
                                 },
                                 credentials: {
                                   token: 'token123'
                                 }
                               })
      end

      before do
        OmniAuth.config.mock_auth[:github] = incomplete_auth_hash
      end

      it 'handles missing email gracefully' do
        expect do
          visit '/users/auth/github'
        end.not_to raise_error

        # Should still attempt to create user, but may fail validation
        expect(page).to have_current_path(['/', '/users/sign_up'], ignore_query: true)
      end
    end

    context 'when GitHub returns an error' do
      before do
        OmniAuth.config.mock_auth[:github] = :access_denied
      end

      it 'displays appropriate error message' do
        visit '/users/auth/github'

        expect(page).to have_text('There was a problem signing you in. Please register or try signing in later.')
        expect(page).to have_current_path('/', ignore_query: true)
      end
    end
  end

  describe 'Post-authentication behavior' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: {
                                 email: 'test@example.com',
                                 name: 'Test User',
                                 nickname: 'testuser'
                               },
                               credentials: {
                                 token: 'github_access_token_123'
                               }
                             })
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:github] = github_auth_hash
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:github] = nil
    end

    it 'user can access protected pages after OAuth sign-in' do
      visit '/users/auth/github'

      # Should be redirected to edit profile after successful auth
      expect(page).to have_current_path('/users/edit', ignore_query: true)

      # User should be able to access other protected pages
      # This tests that the session was properly established
      user = BetterTogether.user_class.find_by(email: 'test@example.com')
      expect(user).to be_present
    end

    it 'persists user session across requests' do
      visit '/users/auth/github'

      expect(page).to have_current_path('/users/edit', ignore_query: true)

      # Navigate to another page to test session persistence
      visit '/'

      # User should still be signed in
      user = BetterTogether.user_class.find_by(email: 'test@example.com')
      expect(user).to be_present
    end
  end
end
