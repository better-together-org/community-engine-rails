# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Users::OmniauthCallbacksController, :skip_host_setup do
  routes { BetterTogether::Engine.routes }

  include Devise::Test::ControllerHelpers

  def configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public', host_url: 'http://localhost:3000') unless host_platform.host_url.present?
    else
      host_platform = FactoryBot.create(:better_together_platform, :host, privacy: 'public', host_url: 'http://localhost:3000')
    end

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    host_platform
  end

  let(:platform) { configure_host_platform }
  let(:community) { platform.community }
  let!(:github_platform) { create(:better_together_platform, :oauth_provider, identifier: 'github', name: 'GitHub') }
  let(:devise_mapping) { Devise.mappings[:user] }

  before do
    # Set up test platform for host application
    platform # Ensure platform is created
    request.host = 'localhost' # Use a simple hostname string
    # Set Devise mapping for controller tests
    @request.env['devise.mapping'] = devise_mapping # rubocop:todo RSpec/InstanceVariable
  end

  describe 'GitHub OAuth callback', :no_auth do
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
      # Mock the OmniAuth auth hash
      request.env['omniauth.auth'] = github_auth_hash
    end

    context 'when user does not exist and PersonPlatformIntegration does not exist' do
      it 'creates a new user and PersonPlatformIntegration' do
        expect do
          get :github
        end.to change(BetterTogether.user_class, :count).by(1)
           .and change(BetterTogether::PersonPlatformIntegration, :count).by(1)
      end

      it 'creates PersonPlatformIntegration with correct attributes' do
        get :github

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq('123456')
        expect(integration.access_token).to eq('github_access_token_123')
        expect(integration.access_token_secret).to eq('github_secret_456')
        expect(integration.handle).to eq('testuser')
        expect(integration.name).to eq('Test User')
        expect(integration.profile_url).to eq('https://github.com/testuser')
      end

      it 'creates user with correct attributes' do
        get :github

        user = BetterTogether.user_class.last
        expect(user.email).to eq('test@example.com')
        expect(user.confirmed_at).to be_present # Should be confirmed due to skip_confirmation!
        expect(user.person.name).to eq('Test User')
        expect(user.person.handle).to eq('testuser')
      end

      it 'signs in the user and redirects to agreements page' do
        get :github

        user = BetterTogether.user_class.last
        expect(controller.current_user).to eq(user)
        # OAuth users are redirected to agreements page after onboarding completes
        expect(response).to redirect_to(better_together.agreements_status_path(locale: I18n.locale))
      end

      it 'sets alert flash message about agreements' do
        get :github

        # User is redirected to accept agreements, not shown success message yet
        expect(flash[:alert]).to eq(I18n.t('better_together.agreements.status.acceptance_required'))
      end

      it 'creates community membership for new OAuth user' do
        expect do
          get :github
        end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

        user = BetterTogether.user_class.last
        membership = user.person.person_community_memberships.last
        expect(membership.joinable).to eq(community)
        expect(membership.status).to eq('active') # OAuth users skip confirmation
      end

      it 'creates community membership with correct default role' do
        get :github

        user = BetterTogether.user_class.last
        membership = user.person.person_community_memberships.last
        expect(membership.role).to be_present
        expect(membership.role.resource_type).to eq('BetterTogether::Community')
      end
    end

    context 'when PersonPlatformIntegration already exists' do
      let!(:existing_integration) do
        create(:person_platform_integration,
               provider: 'github',
               uid: '123456',
               access_token: 'old_token',
               access_token_secret: 'old_secret')
      end

      it 'updates existing PersonPlatformIntegration' do
        expect do
          get :github
        end.not_to change(BetterTogether::PersonPlatformIntegration, :count)

        existing_integration.reload
        expect(existing_integration.access_token).to eq('github_access_token_123')
        expect(existing_integration.access_token_secret).to eq('github_secret_456')
        expect(existing_integration.handle).to eq('testuser')
        expect(existing_integration.name).to eq('Test User')
      end

      it 'signs in the existing user' do
        get :github

        expect(controller.current_user).to eq(existing_integration.user)
      end
    end

    context 'when user exists with same email but no integration' do
      let!(:existing_user) { create(:user, email: 'test@example.com') }

      it 'does not create a new user' do
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)
      end

      it 'creates PersonPlatformIntegration linked to existing user' do
        get :github

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.user).to eq(existing_user)
        expect(integration.person).to eq(existing_user.person)
      end

      it 'signs in the existing user' do
        get :github

        expect(controller.current_user).to eq(existing_user)
      end
    end

    context 'when current_user is signed in' do
      let(:current_user) { create(:user) }

      before do
        sign_in current_user
      end

      it 'links integration to current user instead of creating new user' do
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.user).to eq(current_user)
        expect(integration.person).to eq(current_user.person)
      end
    end

    context 'when user creation fails' do
      before do
        # Mock user_class.from_omniauth to return nil (simulating failure)
        allow(BetterTogether.user_class).to receive(:from_omniauth).and_return(nil)
      end

      it 'sets alert flash message and redirects to registration' do
        get :github

        expect(flash[:alert]).to eq(I18n.t('devise_omniauth_callbacks.failure',
                                           kind: 'Github',
                                           reason: 'test@example.com is not authorized'))
        expect(response).to redirect_to(controller.new_user_registration_path)
      end

      it 'does not sign in any user' do
        get :github

        expect(controller.current_user).to be_nil
      end
    end

    context 'when auth hash is missing required info' do
      let(:incomplete_auth_hash) do
        OmniAuth::AuthHash.new({
                                 provider: 'github',
                                 uid: '123456',
                                 info: {
                                   # Missing email
                                   name: 'Test User'
                                 },
                                 credentials: {
                                   token: 'github_access_token_123'
                                 }
                               })
      end

      before do
        request.env['omniauth.auth'] = incomplete_auth_hash
      end

      it 'handles missing email gracefully' do
        expect do
          get :github
        end.not_to raise_error
      end
    end
  end

  describe '#failure', :skip do
    # Skipped: Calling this method directly requires controller state (@_response)
    # that isn't properly set up in controller specs. The failure functionality
    # is tested via integration tests and real OAuth flows.
  end

  describe 'private methods' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: { email: 'test@example.com' },
                               credentials: { token: 'token123' }
                             })
    end

    before do
      request.env['omniauth.auth'] = github_auth_hash
    end

    describe '#auth' do
      it 'returns the omniauth auth hash from request env' do
        controller.send(:auth)
        expect(controller.send(:auth)).to eq(github_auth_hash)
      end
    end

    describe '#set_person_platform_integration' do
      context 'when integration exists' do # rubocop:todo RSpec/NestedGroups
        let!(:existing_integration) do
          create(:person_platform_integration, provider: 'github', uid: '123456')
        end

        it 'finds and sets the existing integration' do
          controller.send(:set_person_platform_integration)
          expect(controller.person_platform_integration).to eq(existing_integration)
        end
      end

      context 'when integration does not exist' do # rubocop:todo RSpec/NestedGroups
        it 'sets person_platform_integration to nil' do
          controller.send(:set_person_platform_integration)
          expect(controller.person_platform_integration).to be_nil
        end
      end
    end

    describe '#set_user' do
      let(:mock_user) { create(:user) }

      before do
        controller.send(:set_person_platform_integration)
        allow(BetterTogether.user_class).to receive(:from_omniauth)
          .and_return(mock_user)
      end

      it 'calls from_omniauth with invitations parameter' do
        expect(BetterTogether.user_class).to receive(:from_omniauth)
          .with(hash_including(
                  person_platform_integration: controller.person_platform_integration,
                  auth: github_auth_hash,
                  current_user: nil,
                  invitations: {}
                ))

        controller.send(:set_user)
      end

      it 'sets the user' do
        controller.send(:set_user)
        expect(controller.user).to eq(mock_user)
      end
    end

    describe '#handle_auth', :skip do
      # Skipped: These tests require complex controller state setup including
      # signed-in users and response delegation that doesn't work well with
      # controller specs. The functionality is tested via integration tests.
    end
  end

  describe 'before_actions' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: { email: 'test@example.com' },
                               credentials: { token: 'token123' }
                             })
    end

    before do
      request.env['omniauth.auth'] = github_auth_hash
    end

    it 'calls set_person_platform_integration before github action' do
      expect(controller).to receive(:set_person_platform_integration).and_call_original
      get :github
    end

    it 'calls set_user before github action' do
      expect(controller).to receive(:set_user).and_call_original
      get :github
    end

    it 'does not call set_person_platform_integration for failure action', :skip do
      # Skipped: failure route not defined in test environment
    end

    it 'does not call set_user for failure action', :skip do
      # Skipped: failure route not defined in test environment
    end
  end
end
