# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/better_together/person_platform_integrations', :as_user do
  let(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }

  # Create external OAuth platforms for testing
  let!(:github_platform) do
    create(:better_together_platform,
           :external,
           identifier: 'github',
           name: 'GitHub',
           url: 'https://github.com',
           privacy: 'public')
  end

  let!(:facebook_platform) do
    create(:better_together_platform,
           :external,
           identifier: 'facebook',
           name: 'Facebook',
           url: 'https://facebook.com',
           privacy: 'public')
  end

  let(:valid_attributes) do
    {
      provider: 'github',
      uid: '123456',
      access_token: 'test_token',
      handle: 'testuser',
      name: 'Test User',
      profile_url: 'https://github.com/testuser',
      user_id: user.id,
      person_id: person.id,
      platform_id: github_platform.id
    }
  end

  let(:invalid_attributes) do
    {
      provider: '',
      uid: '',
      user_id: nil
    }
  end

  describe 'GET /index' do
    it 'renders a successful response' do
      create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      get better_together.person_platform_integrations_path(locale: I18n.default_locale)
      expect(response).to be_successful
    end

    it 'lists all person_platform_integrations' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      get better_together.person_platform_integrations_path(locale: I18n.default_locale)
      expect(response.body).to include(integration.provider)
    end
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      get better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response).to be_successful
    end

    it 'displays integration details' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      get better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response.body).to include(integration.handle)
    end
  end

  describe 'GET /new' do
    it 'renders a successful response' do
      get better_together.new_person_platform_integration_path(locale: I18n.default_locale)
      expect(response).to be_successful
    end
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      get better_together.edit_person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new PersonPlatformIntegration' do
        expect do
          post better_together.person_platform_integrations_path(locale: I18n.default_locale),
               params: { person_platform_integration: valid_attributes }
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)
      end

      it 'redirects to the created person_platform_integration' do
        post better_together.person_platform_integrations_path(locale: I18n.default_locale),
             params: { person_platform_integration: valid_attributes }
        expect(response).to redirect_to(better_together.person_platform_integration_path(
                                          BetterTogether::PersonPlatformIntegration.last,
                                          locale: I18n.default_locale
                                        ))
      end

      it 'encrypts sensitive tokens' do
        post better_together.person_platform_integrations_path(locale: I18n.default_locale),
             params: { person_platform_integration: valid_attributes }

        integration = BetterTogether::PersonPlatformIntegration.last
        # Token should be encrypted in database but accessible via getter
        expect(integration.access_token).to eq('test_token')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new PersonPlatformIntegration' do
        expect do
          post better_together.person_platform_integrations_path(locale: I18n.default_locale),
               params: { person_platform_integration: invalid_attributes }
        end.not_to change(BetterTogether::PersonPlatformIntegration, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post better_together.person_platform_integrations_path(locale: I18n.default_locale),
             params: { person_platform_integration: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH /update' do
    let(:integration) { create(:person_platform_integration, :github, user:, person:, platform: github_platform) }

    let(:new_attributes) do
      {
        handle: 'updatedhandle',
        name: 'Updated Name'
      }
    end

    context 'with valid parameters' do
      it 'updates the requested person_platform_integration' do
        patch better_together.person_platform_integration_path(integration, locale: I18n.default_locale),
              params: { person_platform_integration: new_attributes }
        integration.reload
        expect(integration.handle).to eq('updatedhandle')
        expect(integration.name).to eq('Updated Name')
      end

      it 'redirects to the person_platform_integration' do
        patch better_together.person_platform_integration_path(integration, locale: I18n.default_locale),
              params: { person_platform_integration: new_attributes }
        integration.reload
        expect(response).to redirect_to(better_together.person_platform_integration_path(
                                          integration,
                                          locale: I18n.default_locale
                                        ))
      end
    end

    context 'with invalid parameters' do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        patch better_together.person_platform_integration_path(integration, locale: I18n.default_locale),
              params: { person_platform_integration: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested person_platform_integration' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      expect do
        delete better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      end.to change(BetterTogether::PersonPlatformIntegration, :count).by(-1)
    end

    it 'redirects to the person_platform_integrations list' do
      integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
      delete better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response.location).to include('/person_platform_integrations')
    end
  end

  describe 'OAuth-specific functionality' do
    context 'when integration is expired' do
      it 'identifies expired integrations' do
        integration = create(:person_platform_integration, :github, :expired, user:, person:, platform: github_platform)
        expect(integration.expired?).to be true
      end
    end

    context 'when integration has no expiration' do
      it 'does not expire' do
        integration = create(:person_platform_integration, :github, :without_expiration, user:, person:, platform: github_platform)
        expect(integration.expired?).to be false
      end
    end

    context 'with multiple OAuth providers' do
      it 'can create integrations for different providers' do
        github_integration = create(:person_platform_integration, :github, user:, person:, platform: github_platform)
        facebook_integration = create(:person_platform_integration, :facebook, user:, person:, platform: facebook_platform)

        expect(github_integration.provider).to eq('github')
        expect(facebook_integration.provider).to eq('facebook')
        expect(github_integration.platform).not_to eq(facebook_integration.platform)
      end
    end
  end

  # CRITICAL SECURITY TESTS - Last OAuth Integration Protection
  describe 'DELETE /destroy - Last OAuth Integration Protection', :skip_host_setup do
    before do
      # Create fresh platform for these tests
      configure_host_platform
    end

    context 'when OauthUser has only one integration' do
      let(:oauth_user) { create(:user, :oauth_user, :confirmed, email: 'oauth@example.com') }
      let(:oauth_person) { oauth_user.person }
      let(:last_integration) do
        create(:person_platform_integration, :github,
               user: oauth_user,
               person: oauth_person,
               platform: github_platform)
      end

      before do
        # Authenticate as the oauth_user
        sign_in oauth_user
      end

      it 'prevents deletion with unprocessable_entity status' do
        delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'shows cannot_delete_last_oauth alert message' do
        last_integration # Force creation
        delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale)
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('OAuth')
      end

      it 'includes provider name in alert message' do
        last_integration # Force creation
        delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale)
        expect(flash[:alert]).to include('Github')
      end

      it 'does not destroy the integration' do
        last_integration # Force creation
        expect do
          delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale)
        end.not_to change(BetterTogether::PersonPlatformIntegration, :count)
      end

      it 'redirects to integrations list' do
        delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale)
        expect(response.location).to include('/person_platform_integrations')
      end

      context 'with Turbo Stream request' do # rubocop:disable RSpec/NestedGroups
        it 'returns turbo stream with flash message' do
          delete better_together.person_platform_integration_path(last_integration, locale: I18n.default_locale),
                 headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

          expect(response.content_type).to match(/turbo-stream/)
          expect(response.body).to include('turbo-stream')
          expect(response.body).to include('flash_messages')
        end
      end
    end

    context 'when OauthUser has multiple integrations' do
      let(:oauth_user) { create(:user, :oauth_user, :confirmed, email: 'oauth_multi@example.com') }
      let(:oauth_person) { oauth_user.person }
      let!(:github_integration) do
        create(:person_platform_integration, :github,
               user: oauth_user,
               person: oauth_person,
               platform: github_platform)
      end
      let!(:facebook_integration) do
        create(:person_platform_integration, :facebook,
               user: oauth_user,
               person: oauth_person,
               platform: facebook_platform)
      end

      before do
        sign_in oauth_user
      end

      it 'allows deletion when user has other integrations' do
        expect do
          delete better_together.person_platform_integration_path(github_integration, locale: I18n.default_locale)
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(-1)
      end

      it 'returns successful redirect after deletion' do
        delete better_together.person_platform_integration_path(github_integration, locale: I18n.default_locale)
        expect(response).to have_http_status(:see_other)
      end

      it 'shows success message after deletion' do
        delete better_together.person_platform_integration_path(github_integration, locale: I18n.default_locale)
        expect(flash[:success]).to be_present
      end
    end

    context 'when regular User (with password) has one integration' do
      let(:regular_user) { create(:user, :confirmed, email: 'regular@example.com', password: 'VerySecure Password 123!@#') }
      let(:regular_person) { regular_user.person }
      let(:only_integration) do
        create(:person_platform_integration, :github,
               user: regular_user,
               person: regular_person,
               platform: github_platform)
      end

      before do
        sign_in regular_user
      end

      it 'allows deletion for users with password' do
        only_integration # Force creation
        expect do
          delete better_together.person_platform_integration_path(only_integration, locale: I18n.default_locale)
        end.to change(BetterTogether::PersonPlatformIntegration, :count).by(-1)
      end

      it 'returns successful response' do
        delete better_together.person_platform_integration_path(only_integration, locale: I18n.default_locale)
        expect(response).to have_http_status(:see_other)
      end

      it 'does not show lockout warning' do
        delete better_together.person_platform_integration_path(only_integration, locale: I18n.default_locale)
        expect(flash[:alert]).to be_nil
      end
    end

    context 'edge case: OauthUser type check' do
      let(:oauth_user) { create(:user, :oauth_user, :confirmed, email: 'edge@example.com') }
      let(:oauth_person) { oauth_user.person }
      let(:integration) do
        create(:person_platform_integration, :github,
               user: oauth_user,
               person: oauth_person,
               platform: github_platform)
      end

      before do
        sign_in oauth_user
      end

      it 'correctly identifies OauthUser type' do
        expect(oauth_user.type).to eq('BetterTogether::OauthUser')
      end

      it 'counts integrations correctly' do
        integration # Create the integration
        expect(oauth_user.person_platform_integrations.count).to eq(1)
      end

      it 'applies protection based on type and count' do
        delete better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
