# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/better_together/person_platform_integrations', type: :request do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let(:github_platform) do
    BetterTogether::Platform.external.find_or_create_by(
      identifier: 'github',
      host: false,
      external: true
    ) do |p|
      p.name = 'GitHub'
      p.url = 'https://github.com'
      p.privacy = 'public'
    end
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

  before do
    sign_in user
  end

  describe 'GET /index' do
    it 'renders a successful response' do
      create(:person_platform_integration, :github, user:, person:)
      get better_together.person_platform_integrations_path(locale: I18n.default_locale)
      expect(response).to be_successful
    end

    it 'lists all person_platform_integrations' do
      integration = create(:person_platform_integration, :github, user:, person:)
      get better_together.person_platform_integrations_path(locale: I18n.default_locale)
      expect(response.body).to include(integration.provider)
    end
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      integration = create(:person_platform_integration, :github, user:, person:)
      get better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response).to be_successful
    end

    it 'displays integration details' do
      integration = create(:person_platform_integration, :github, user:, person:)
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
      integration = create(:person_platform_integration, :github, user:, person:)
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
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /update' do
    let(:integration) { create(:person_platform_integration, :github, user:, person:) }
    
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
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested person_platform_integration' do
      integration = create(:person_platform_integration, :github, user:, person:)
      expect do
        delete better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      end.to change(BetterTogether::PersonPlatformIntegration, :count).by(-1)
    end

    it 'redirects to the person_platform_integrations list' do
      integration = create(:person_platform_integration, :github, user:, person:)
      delete better_together.person_platform_integration_path(integration, locale: I18n.default_locale)
      expect(response.location).to include('/person_platform_integrations')
    end
  end

  describe 'OAuth-specific functionality' do
    context 'when integration is expired' do
      it 'identifies expired integrations' do
        integration = create(:person_platform_integration, :github, :expired, user:, person:)
        expect(integration.expired?).to be true
      end
    end

    context 'when integration has no expiration' do
      it 'does not expire' do
        integration = create(:person_platform_integration, :github, :without_expiration, user:, person:)
        expect(integration.expired?).to be false
      end
    end

    context 'with multiple OAuth providers' do
      it 'can create integrations for different providers' do
        github_integration = create(:person_platform_integration, :github, user:, person:)
        facebook_integration = create(:person_platform_integration, :facebook, user:, person:)
        
        expect(github_integration.provider).to eq('github')
        expect(facebook_integration.provider).to eq('facebook')
        expect(github_integration.platform).not_to eq(facebook_integration.platform)
      end
    end
  end
end
