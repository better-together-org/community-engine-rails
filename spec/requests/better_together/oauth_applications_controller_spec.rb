# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::OauthApplicationsController' do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }

  describe 'GET /host/oauth_applications (index)', :as_platform_manager do
    let!(:oauth_app) do
      create(:better_together_oauth_application,
             name: 'My Test App',
             owner: platform_manager.person)
    end

    it 'renders the index page successfully' do
      get better_together.oauth_applications_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'displays OAuth application names' do
      get better_together.oauth_applications_path(locale:)
      expect_html_content('My Test App')
    end

    it 'includes a link to create a new application' do
      get better_together.oauth_applications_path(locale:)
      expect(response.body).to include(better_together.new_oauth_application_path(locale:))
    end
  end

  describe 'GET /host/oauth_applications/:id (show)', :as_platform_manager do
    let(:oauth_app) do
      create(:better_together_oauth_application,
             name: 'Show Test App',
             owner: platform_manager.person)
    end

    it 'renders the show page successfully' do
      get better_together.oauth_application_path(locale:, id: oauth_app.id)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the application name' do
      get better_together.oauth_application_path(locale:, id: oauth_app.id)
      expect_html_content('Show Test App')
    end

    it 'displays the client ID' do
      get better_together.oauth_application_path(locale:, id: oauth_app.id)
      expect_html_content(oauth_app.uid)
    end
  end

  describe 'GET /host/oauth_applications/new', :as_platform_manager do
    it 'renders the new application form' do
      get better_together.new_oauth_application_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'includes form fields' do
      get better_together.new_oauth_application_path(locale:)
      expect(response.body).to include('oauth_application[name]')
      expect(response.body).to include('oauth_application[redirect_uri]')
    end
  end

  describe 'POST /host/oauth_applications', :as_platform_manager do
    let(:valid_params) do
      {
        oauth_application: {
          name: 'New OAuth App',
          redirect_uri: 'https://example.com/callback',
          scopes: 'read write',
          confidential: true
        }
      }
    end

    it 'creates a new OAuth application' do
      expect do
        post better_together.oauth_applications_path(locale:), params: valid_params
      end.to change(BetterTogether::OauthApplication, :count).by(1)
    end

    it 'redirects after successful creation' do
      post better_together.oauth_applications_path(locale:), params: valid_params
      expect(response).to have_http_status(:found)
    end

    it 'assigns the current user as the application owner' do
      post better_together.oauth_applications_path(locale:), params: valid_params
      app = BetterTogether::OauthApplication.last
      expect(app.owner).to eq(platform_manager.person)
    end

    it 'generates a client ID and secret' do
      post better_together.oauth_applications_path(locale:), params: valid_params
      app = BetterTogether::OauthApplication.last
      expect(app.uid).to be_present
      expect(app.secret).to be_present
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          oauth_application: {
            name: ''
          }
        }
      end

      it 'does not create an OAuth application' do
        expect do
          post better_together.oauth_applications_path(locale:), params: invalid_params
        end.not_to change(BetterTogether::OauthApplication, :count)
      end

      it 'returns unprocessable entity status' do
        post better_together.oauth_applications_path(locale:), params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /host/oauth_applications/:id/edit', :as_platform_manager do
    let(:oauth_app) do
      create(:better_together_oauth_application,
             name: 'Edit Test App',
             owner: platform_manager.person)
    end

    it 'renders the edit form' do
      get better_together.edit_oauth_application_path(locale:, id: oauth_app.id)
      expect(response).to have_http_status(:ok)
    end

    it 'populates the form with existing data' do
      get better_together.edit_oauth_application_path(locale:, id: oauth_app.id)
      expect_html_content('Edit Test App')
    end
  end

  describe 'PATCH /host/oauth_applications/:id', :as_platform_manager do
    let(:oauth_app) do
      create(:better_together_oauth_application,
             name: 'Original App Name',
             owner: platform_manager.person)
    end

    let(:update_params) do
      {
        oauth_application: {
          name: 'Updated App Name'
        }
      }
    end

    it 'updates the OAuth application' do
      patch better_together.oauth_application_path(locale:, id: oauth_app.id), params: update_params
      oauth_app.reload
      expect(oauth_app.name).to eq('Updated App Name')
    end

    it 'redirects after successful update' do
      patch better_together.oauth_application_path(locale:, id: oauth_app.id), params: update_params
      expect(response).to have_http_status(:found)
    end
  end

  describe 'DELETE /host/oauth_applications/:id', :as_platform_manager do
    let!(:oauth_app) do
      create(:better_together_oauth_application,
             name: 'Delete Test App',
             owner: platform_manager.person)
    end

    it 'deletes the OAuth application' do
      expect do
        delete better_together.oauth_application_path(locale:, id: oauth_app.id)
      end.to change(BetterTogether::OauthApplication, :count).by(-1)
    end

    it 'redirects to the index page' do
      delete better_together.oauth_application_path(locale:, id: oauth_app.id)
      expect(response).to redirect_to(better_together.oauth_applications_path(locale:))
    end
  end

  describe 'access control' do
    context 'when not authenticated', :unauthenticated do
      it 'denies access to index' do
        get better_together.oauth_applications_path(locale:)
        # Routes are behind authenticated constraint, so unauthenticated
        # users receive 404 rather than a redirect to sign in
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
