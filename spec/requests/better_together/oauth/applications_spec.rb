# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Applications API', :as_user do
  let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  describe 'GET /api/oauth_applications' do
    let!(:owned_app) { create(:oauth_application, owner: person, name: 'My App 1') }
    let!(:second_owned_app) { create(:oauth_application, owner: person, name: 'My App 2') }
    let!(:other_app) { create(:oauth_application, name: 'Other App') }

    it 'returns only applications owned by the current user' do
      get '/api/oauth_applications', headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['applications'].length).to eq(2)

      app_names = json['applications'].map { |a| a['name'] }
      expect(app_names).to include('My App 1', 'My App 2')
      expect(app_names).not_to include('Other App')
    end
  end

  describe 'POST /api/oauth_applications' do
    let(:valid_params) do
      {
        oauth_application: {
          name: 'Test Application',
          redirect_uri: 'https://example.com/callback',
          scopes: 'read write',
          confidential: true
        }
      }
    end

    it 'creates a new OAuth application' do
      expect do
        post '/api/oauth_applications', params: valid_params.to_json, headers: auth_headers
      end.to change(BetterTogether::OauthApplication, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['application']['name']).to eq('Test Application')
      # Secret should be included on creation
      expect(json['application']['secret']).to be_present
      expect(json['application']['uid']).to be_present
    end

    it 'returns errors for invalid params' do
      post '/api/oauth_applications',
           params: { oauth_application: { name: '' } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /api/oauth_applications/:id' do
    let(:oauth_app) { create(:oauth_application, owner: person) }

    it 'returns the application details' do
      get "/api/oauth_applications/#{oauth_app.id}", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['application']['name']).to eq(oauth_app.name)
      # Secret should NOT be included on show
      expect(json['application']).not_to have_key('secret')
    end

    it 'returns 404 for applications not owned by the user' do
      other_oauth_app = create(:oauth_application)

      get "/api/oauth_applications/#{other_oauth_app.id}", headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/oauth_applications/:id' do
    let(:oauth_app) { create(:oauth_application, owner: person) }

    it 'updates the application' do
      patch "/api/oauth_applications/#{oauth_app.id}",
            params: { oauth_application: { name: 'Updated Name' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['application']['name']).to eq('Updated Name')
    end
  end

  describe 'DELETE /api/oauth_applications/:id' do
    let!(:oauth_app) { create(:oauth_application, owner: person) }

    it 'deletes the application' do
      expect do
        delete "/api/oauth_applications/#{oauth_app.id}", headers: auth_headers
      end.to change(BetterTogether::OauthApplication, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
