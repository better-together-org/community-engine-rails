# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups, RSpec/MultipleMemoizedHelpers, RSpec/SpecFilePathFormat
RSpec.describe BetterTogether::Users::OmniauthCallbacksController, :no_auth, :omniauth, :skip_host_setup do
  routes { BetterTogether::Engine.routes }
  include Devise::Test::ControllerHelpers

  def configure_host_platform # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    host_platform = BetterTogether::Platform.find_by(host: true)
    unless host_platform
      begin
        host_community = BetterTogether::Community.find_or_create_by!(host: true) do |c|
          c.name = "Test Community #{SecureRandom.uuid}"
          c.description = 'Test community for OAuth flows'
          c.identifier = "test-community-#{SecureRandom.hex(10)}"
          c.privacy = 'public'
          c.protected = true
        end

        host_platform = BetterTogether::Platform.find_or_create_by!(host: true) do |p|
          p.name = host_community.name
          p.description = host_community.description
          p.identifier = host_community.identifier
          p.host_url = 'http://localhost:3000'
          p.time_zone = 'UTC'
          p.privacy = 'public'
          p.protected = true
          p.community = host_community
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        if e.message.include?('Community host can only be set for one record') ||
           e.message.include?('Platform host can only be set for one record') ||
           e.message.include?('duplicate key')
          sleep(0.1)
          host_platform = BetterTogether::Platform.find_by(host: true)
          raise e unless host_platform
        else
          raise e
        end
      end
    end

    # Ensure host_url is set if it wasn't
    host_platform.update!(host_url: 'http://localhost:3000') unless host_platform.host_url.present?

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    host_platform
  end
  let!(:platform) { configure_host_platform }
  let!(:community) { platform.community }
  let!(:github_platform) do
    BetterTogether::Platform.find_or_create_by!(identifier: 'github') do |github|
      github.external = true
      github.host = false
      github.name = 'GitHub'
      github.url = 'https://github.com'
      github.privacy = 'public'
      github.time_zone = 'UTC'
    end
  end
  let(:devise_mapping) { Devise.mappings[:user] }

  # Helper to create GitHub auth hash with custom options
  # rubocop:disable Metrics/MethodLength
  def github_auth_hash(email: unique_email, uid: unique_oauth_uid, **)
    github_oauth_hash(email: email, uid: uid, **)
  end
  # rubocop:enable Metrics/MethodLength

  before do
    request.host = 'localhost'
    @request.env['devise.mapping'] = devise_mapping # rubocop:todo RSpec/InstanceVariable
  end

  describe 'OAuth Authentication Scenarios', :no_auth do
    context 'when new user signs up via OAuth' do
      let(:oauth_email) { unique_email }
      let(:oauth_uid) { unique_oauth_uid }

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: oauth_uid)
      end

      it 'creates new user and signs them in', :aggregate_failures do
        expect do
          get :github
        end.to change(BetterTogether.user_class, :count).by(1)

        new_user = BetterTogether.user_class.find_by(email: oauth_email)
        expect(new_user).to be_present
        expect(new_user.confirmed_at).to be_present

        # User should be signed in
        expect(controller.current_user).to eq(new_user)
      end

      it 'creates PersonPlatformIntegration record', :aggregate_failures do
        expect do
          get :github
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.provider).to eq('github')
        expect(integration.platform).to eq(github_platform)
        expect(integration.uid).to eq(oauth_uid)
      end
    end

    context 'when existing user (created via email/password) authenticates via OAuth' do
      let(:existing_email) { unique_email }
      let(:existing_uid) { unique_oauth_uid }
      let!(:existing_user) do
        create(:better_together_user, email: existing_email, password: 'MyStr0ng!Phrase#2024')
      end

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: existing_email, uid: existing_uid)

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: existing_uid
        ).delete_all
      end

      it 'signs in the existing user without creating a new account' do
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)

        # User should be signed in
        expect(controller.current_user).to eq(existing_user)
      end

      it 'creates PersonPlatformIntegration linking OAuth to existing account' do
        expect do
          get :github
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.user).to eq(existing_user)
        expect(integration.provider).to eq('github')
        expect(integration.uid).to eq(existing_uid)
      end
    end

    context 'when already-signed-in user connects additional OAuth account' do
      let(:signed_in_email) { 'signedin@example.com' }
      let!(:signed_in_user) do
        create(:better_together_user, email: signed_in_email, password: 'MyStr0ng!Phrase#2024')
      end

      before do
        sign_in signed_in_user
        request.env['omniauth.auth'] = github_auth_hash(email: signed_in_email, uid: '345678')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '345678'
        ).delete_all
      end

      it 'does not create new user account' do
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)
      end

      it 'creates PersonPlatformIntegration for the signed-in user' do
        skip 'Controller specs have limitations with signed-in OAuth scenarios - use request specs instead'
        expect do
          get :github
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)

        integration = BetterTogether::PersonPlatformIntegration.last
        expect(integration.user).to eq(signed_in_user)
        expect(integration.uid).to eq('345678')
      end

      it 'redirects to settings integrations page' do
        skip 'Controller specs have limitations with signed-in OAuth scenarios - use request specs instead'
        get :github

        # Should redirect to settings integrations tab
        expect(response.location).to include('/settings')
        expect(response.location).to include('integrations')
      end
    end

    context 'when returning OAuth user signs in again' do
      let(:oauth_email) { 'returning@example.com' }
      let!(:existing_user) do
        create(:better_together_user, email: oauth_email, password: 'MyStr0ng!Phrase#2024')
      end
      let!(:existing_integration) do
        create(:better_together_person_platform_integration,
               user: existing_user,
               person: existing_user.person,
               platform: github_platform,
               provider: 'github',
               uid: '555555')
      end

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '555555')
      end

      it 'signs in the user without creating new records' do
        skip 'Controller specs have limitations with OAuth scenarios - use request specs instead'
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)
          .and not_change(BetterTogether::PersonPlatformIntegration, :count)

        expect(controller.current_user).to eq(existing_user)
      end

      it 'redirects to root path' do
        get :github

        expect(response.location).to include('/en')
      end
    end
  end

  describe 'OAuth with Unaccepted Agreements', :no_auth do
    let(:oauth_email) { 'needsagreements@example.com' }
    let!(:required_agreement) do
      BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') do |a|
        a.title = 'Terms of Service'
      end
    end

    context 'when new user signs up via OAuth with unaccepted agreements' do
      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '111111')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '111111'
        ).delete_all
      end

      it 'creates and signs in the user' do
        get :github

        new_user = BetterTogether.user_class.find_by(email: oauth_email)
        expect(new_user).to be_present
        expect(controller.current_user).to eq(new_user)
      end

      it 'redirects to agreements status page' do
        get :github

        expect(response.location).to include('/agreements/status')
      end

      it 'shows agreement acceptance required message' do
        get :github

        expect(flash[:alert]).to match(/agreement/i)
      end
    end

    context 'when existing user authenticates via OAuth with unaccepted agreements' do
      let!(:existing_user) do
        create(:better_together_user, email: oauth_email, password: 'MyStr0ng!Phrase#2024')
      end

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '222222')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '222222'
        ).delete_all
      end

      it 'signs in the user and redirects to agreements' do
        get :github

        expect(controller.current_user).to eq(existing_user)
        expect(response.location).to include('/agreements/status')
      end
    end

    context 'when already-signed-in user connects OAuth with unaccepted agreements' do
      let!(:signed_in_user) do
        create(:better_together_user, email: oauth_email, password: 'MyStr0ng!Phrase#2024')
      end

      before do
        sign_in signed_in_user
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '333333')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '333333'
        ).delete_all
      end

      it 'does not sign in again (user already signed in)' do
        # Track sign_in calls
        allow(controller).to receive(:sign_in).and_call_original

        get :github

        # sign_in should not be called since user was already signed in
        expect(controller).not_to have_received(:sign_in)
      end

      it 'redirects to agreements status page' do
        skip 'Controller specs have limitations with signed-in OAuth scenarios - use request specs instead'
        get :github

        expect(response.location).to include('/agreements/status')
      end
    end
  end

  describe 'OAuth with Invitation Requirement', :no_auth do
    before do
      # Enable invitation requirement on host platform
      platform.update!(
        settings: platform.settings.merge('requires_invitation' => true)
      )
    end

    context 'when new user attempts OAuth signup without invitation' do
      let(:oauth_email) { 'noinvite@example.com' }

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '444444')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '444444'
        ).delete_all
      end

      it 'rejects the signup and redirects to sign-in page' do
        expect do
          get :github
        end.not_to change(BetterTogether.user_class, :count)

        expect(response.location).to include('/users/sign-in')
        expect(flash[:alert]).to match(/invitation/i)
      end
    end

    context 'when existing user authenticates via OAuth (no invitation needed)' do
      let(:oauth_email) { 'existing_invite@example.com' }
      let!(:existing_user) do
        create(:better_together_user, email: oauth_email, password: 'MyStr0ng!Phrase#2024')
      end

      before do
        request.env['omniauth.auth'] = github_auth_hash(email: oauth_email, uid: '666666')

        # Clean up any existing integrations
        BetterTogether::PersonPlatformIntegration.where(
          provider: 'github',
          uid: '666666'
        ).delete_all
      end

      it 'allows authentication for existing users even when invitations required' do
        skip 'Controller specs have limitations with OAuth scenarios - use request specs instead'
        expect do
          get :github
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)

        # Should redirect to home page (not sign-in page)
        expect(response.location).to include('/en')
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
# rubocop:enable RSpec/NestedGroups, RSpec/MultipleMemoizedHelpers
