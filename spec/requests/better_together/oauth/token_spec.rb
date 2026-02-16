# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Doorkeeper OAuth Token Endpoints', :no_auth do
  describe 'POST /api/oauth/token (client_credentials)' do
    let(:user) { create(:better_together_user, :confirmed) }
    let(:oauth_app) do
      create(:oauth_application,
             owner: user.person,
             scopes: 'read write',
             redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
    end

    it 'issues an access token with client_credentials grant' do
      post '/api/oauth/token', params: {
        grant_type: 'client_credentials',
        client_id: oauth_app.uid,
        client_secret: oauth_app.secret,
        scope: 'read'
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['access_token']).to be_present
      expect(json['token_type']).to eq('Bearer')
      expect(json['expires_in']).to be_present
    end

    it 'rejects invalid client credentials' do
      post '/api/oauth/token', params: {
        grant_type: 'client_credentials',
        client_id: oauth_app.uid,
        client_secret: 'invalid_secret',
        scope: 'read'
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects unknown scopes' do
      post '/api/oauth/token', params: {
        grant_type: 'client_credentials',
        client_id: oauth_app.uid,
        client_secret: oauth_app.secret,
        scope: 'nonexistent_scope'
      }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /api/oauth/revoke' do
    let(:user) { create(:better_together_user, :confirmed) }
    let(:oauth_app) { create(:oauth_application, owner: user.person) }
    let(:access_token) do
      create(:oauth_access_token,
             application: oauth_app,
             resource_owner: user)
    end

    it 'revokes an access token' do
      post '/api/oauth/revoke', params: {
        token: access_token.token,
        client_id: oauth_app.uid,
        client_secret: oauth_app.secret
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(access_token.reload.revoked?).to be true
    end
  end
end
