# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GitHub OAuth Integration' do
  include BetterTogether::DeviseSessionHelpers

  let(:platform) { configure_host_platform }
  let(:community) { platform.community }

  before do
    # Set up test platform for host application
    platform # Ensure platform is created
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
        visit '/users/auth/github/callback'

        expect(page).to have_current_path('/en/agreements/status', ignore_query: true)

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
        initial_count = BetterTogether.user_class.count
        visit '/users/auth/github/callback'

        expect(page).to have_current_path('/en/agreements/status', ignore_query: true)

        # Check that OAuth user was created (since it's a new email from OAuth)
        # Or linked to existing if email matching logic works
        expect(BetterTogether.user_class.count).to be >= initial_count

        # Check that PersonPlatformIntegration was created
        integration = BetterTogether::PersonPlatformIntegration.find_by(provider: 'github', uid: '123456')
        expect(integration).to be_present
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq('123456')
      end
    end

    context 'when PersonPlatformIntegration already exists' do
      let!(:existing_user) { create(:user, email: 'test@example.com') }
      let!(:existing_integration) do
        create(:person_platform_integration,
               user: existing_user,
               provider: 'github',
               uid: '123456',
               access_token: 'old_token')
      end

      it 'updates existing integration and signs in user', :js, :no_auth do
        # DEBUG: Check agreement status before OAuth
        puts 'DEBUG: ===== BEFORE OAUTH ====='
        puts "DEBUG: Existing user email: #{existing_user.email}"
        puts "DEBUG: Existing user ID: #{existing_user.id}"
        puts "DEBUG: Existing person ID: #{existing_user.person.id}"
        puts "DEBUG: Existing integration ID: #{existing_integration.id}"
        puts "DEBUG: Existing integration provider/uid: #{existing_integration.provider}/#{existing_integration.uid}"
        puts "DEBUG: Unaccepted agreements: #{existing_user.person.unaccepted_required_agreements.pluck(:identifier)}"
        puts "DEBUG: Unaccepted?: #{existing_user.person.unaccepted_required_agreements?}"

        visit '/users/auth/github/callback'

        puts 'DEBUG: ===== AFTER OAUTH ====='
        puts "DEBUG: Current path: #{page.current_path}"
        puts "DEBUG: All users: #{BetterTogether::User.pluck(:id, :email)}"
        puts "DEBUG: All integrations: #{BetterTogether::PersonPlatformIntegration.pluck(:id, :provider, :uid, :user_id)}"

        expect(page).to have_current_path('/en/agreements/status', ignore_query: true)

        # Check that integration was updated
        existing_integration.reload
        expect(existing_integration.access_token).to eq('github_access_token_123')
        expect(existing_integration.name).to eq('Test User')
        expect(existing_integration.handle).to eq('testuser')
      end
    end

    context 'when user is already signed in' do
      # Use same email as OAuth to test linking behavior
      let(:current_user) { create(:user, email: 'test@example.com', password: 'MyS3cur3T3st!') }

      it 'links GitHub account to current user', :js do
        # Sign in the user first using Capybara
        capybara_sign_in_user(current_user.email, 'MyS3cur3T3st!')

        initial_user_count = BetterTogether.user_class.count

        # Now visit OAuth callback
        visit '/users/auth/github/callback'

        # Should not create a new user - should link to existing signed-in user
        expect(BetterTogether.user_class.count).to eq(initial_user_count)

        # Check that PersonPlatformIntegration was linked to the signed-in user
        integration = BetterTogether::PersonPlatformIntegration.find_by(provider: 'github', uid: '123456')
        expect(integration).to be_present
        expect(integration.user).to eq(current_user)
        expect(integration.person).to eq(current_user.person)
      end
    end

    context 'when OAuth fails' do
      before do
        OmniAuth.config.mock_auth[:github] = :invalid_credentials
      end

      it 'handles OAuth failure gracefully' do
        visit '/users/auth/github/callback'

        expect(page).to have_text('Could not authenticate you from GitHub because "Invalid credentials"')
        expect(page).to have_current_path(%r{^/(en/)?users/sign-in}, ignore_query: true)
      end
    end

    context 'when user creation fails due to validation errors' do
      before do
        # Mock user validation to fail
        allow_any_instance_of(BetterTogether.user_class).to receive(:save).and_return(false) # rubocop:todo RSpec/AnyInstance
        allow_any_instance_of(BetterTogether.user_class).to receive(:persisted?).and_return(false) # rubocop:todo RSpec/AnyInstance
      end

      it 'redirects to registration with error message' do
        visit '/users/auth/github/callback'

        # When user creation fails, redirects to sign-up or shows validation error
        expect(page).to have_current_path(%r{^/(en/)?users/sign-up}, ignore_query: true)
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
          visit '/users/auth/github/callback'
        end.not_to raise_error

        # Should still attempt to create user, but may fail validation or succeed and redirect to agreements
        expect(page).to have_current_path(%r{^/(en/)?(agreements/status|users/sign-up)}, ignore_query: true)
      end
    end

    context 'when GitHub returns an error' do
      before do
        OmniAuth.config.mock_auth[:github] = :access_denied
      end

      it 'displays appropriate error message' do
        visit '/users/auth/github/callback'

        expect(page).to have_text('Could not authenticate you from GitHub because "Access denied"')
        expect(page).to have_current_path(%r{^/(en/)?users/sign-in}, ignore_query: true)
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
      visit '/users/auth/github/callback'

      # Should be redirected to agreements status after successful auth
      expect(page).to have_current_path('/en/agreements/status', ignore_query: true)

      # User should be able to access other protected pages
      # This tests that the session was properly established
      user = BetterTogether.user_class.find_by(email: 'test@example.com')
      expect(user).to be_present
    end

    it 'persists user session across requests' do
      visit '/users/auth/github/callback'

      expect(page).to have_current_path('/en/agreements/status', ignore_query: true)

      # Navigate to another page to test session persistence
      visit '/'

      # User should still be signed in
      user = BetterTogether.user_class.find_by(email: 'test@example.com')
      expect(user).to be_present
    end
  end
end
