# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth E2E Integration', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }

  describe 'client_credentials grant flow' do
    let(:oauth_app) do
      create(:better_together_oauth_application,
             :with_admin_scope,
             owner: platform_manager_user.person,
             redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
    end

    it 'obtains a token and accesses webhook endpoints API' do
      # Step 1: Request a client_credentials token
      post '/api/oauth/token',
           params: {
             grant_type: 'client_credentials',
             client_id: oauth_app.uid,
             client_secret: oauth_app.plaintext_secret,
             scope: 'read write admin'
           }

      expect(response).to have_http_status(:ok)

      token_json = JSON.parse(response.body)
      access_token = token_json['access_token']
      expect(access_token).to be_present
      expect(token_json['token_type']).to eq('Bearer')

      # Step 2: Use the token to ping the webhook receiver
      post '/api/v1/webhooks/receive',
           params: { event: 'ping' }.to_json,
           headers: {
             'Authorization' => "Bearer #{access_token}",
             'Content-Type' => 'application/json',
             'Accept' => 'application/json'
           }

      expect(response).to have_http_status(:ok)

      ping_json = JSON.parse(response.body)
      expect(ping_json['data']['attributes']['message']).to eq('pong')
    end

    it 'returns error for insufficient scopes' do
      # Create a token with only read scope
      read_only_app = create(:better_together_oauth_application,
                             owner: platform_manager_user.person)

      post '/api/oauth/token',
           params: {
             grant_type: 'client_credentials',
             client_id: read_only_app.uid,
             client_secret: read_only_app.plaintext_secret,
             scope: 'read'
           }

      expect(response).to have_http_status(:ok)
      read_only_token = JSON.parse(response.body)['access_token']

      # Try to call the webhooks receive endpoint which requires write/admin
      post '/api/v1/webhooks/receive',
           params: { event: 'ping' }.to_json,
           headers: {
             'Authorization' => "Bearer #{read_only_token}",
             'Content-Type' => 'application/json',
             'Accept' => 'application/json'
           }

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects expired tokens' do
      expired_token = create(:better_together_oauth_access_token,
                             :expired,
                             :client_credentials,
                             application: oauth_app,
                             scopes: 'read write admin')

      post '/api/v1/webhooks/receive',
           params: { event: 'ping' }.to_json,
           headers: {
             'Authorization' => "Bearer #{expired_token.token}",
             'Content-Type' => 'application/json',
             'Accept' => 'application/json'
           }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects revoked tokens' do
      revoked_token = create(:better_together_oauth_access_token,
                             :revoked,
                             :client_credentials,
                             application: oauth_app,
                             scopes: 'read write admin')

      post '/api/v1/webhooks/receive',
           params: { event: 'ping' }.to_json,
           headers: {
             'Authorization' => "Bearer #{revoked_token.token}",
             'Content-Type' => 'application/json',
             'Accept' => 'application/json'
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'webhook CRUD flow with OAuth' do
    let(:oauth_app) do
      create(:better_together_oauth_application,
             :with_admin_scope,
             owner: platform_manager_user.person)
    end
    let(:oauth_headers) do
      post '/api/oauth/token',
           params: {
             grant_type: 'client_credentials',
             client_id: oauth_app.uid,
             client_secret: oauth_app.plaintext_secret,
             scope: 'read write admin'
           }

      token = JSON.parse(response.body)['access_token']
      {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/vnd.api+json',
        'Accept' => 'application/vnd.api+json'
      }
    end

    it 'creates, reads, and deletes a webhook endpoint via OAuth' do
      # Create
      create_params = {
        data: {
          type: 'webhook_endpoints',
          attributes: {
            name: 'OAuth Test Webhook',
            url: 'https://n8n.example.com/webhook/test',
            events: %w[community.created person.updated],
            active: true
          }
        }
      }

      post '/api/v1/webhook_endpoints',
           params: create_params.to_json,
           headers: oauth_headers

      expect(response).to have_http_status(:created)

      endpoint_id = JSON.parse(response.body)['data']['id']
      expect(endpoint_id).to be_present

      # Read
      get "/api/v1/webhook_endpoints/#{endpoint_id}", headers: oauth_headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['attributes']['name']).to eq('OAuth Test Webhook')

      # Delete
      delete "/api/v1/webhook_endpoints/#{endpoint_id}", headers: oauth_headers
      expect(response).to have_http_status(:no_content)

      # Verify deleted
      get "/api/v1/webhook_endpoints/#{endpoint_id}", headers: oauth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
