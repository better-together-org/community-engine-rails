# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Webhooks', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:oauth_app) do
    create(:oauth_application,
           owner: platform_manager_user.person,
           scopes: 'admin write',
           redirect_uri: 'urn:ietf:wg:oauth:2.0:oob')
  end

  let(:oauth_access_token) do
    post '/api/oauth/token', params: {
      grant_type: 'client_credentials',
      client_id: oauth_app.uid,
      client_secret: oauth_app.secret,
      scope: 'admin'
    }, as: :json

    JSON.parse(response.body).fetch('access_token')
  end

  let(:oauth_headers) do
    {
      'Authorization' => "Bearer #{oauth_access_token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  describe 'POST /api/v1/webhooks/receive' do
    let(:url) { '/api/v1/webhooks/receive' }

    context 'with a ping event' do
      let(:payload) { { event: 'ping' } }

      it 'returns pong response' do
        expect(oauth_access_token).to be_present
        expect(response).to have_http_status(:ok)

        post url, params: payload.to_json, headers: oauth_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('ok')
        expect(json['data']['attributes']['message']).to eq('pong')
      end
    end

    context 'with a sync event' do
      let(:payload) do
        {
          event: 'sync.community',
          payload: {
            name: 'External Community',
            description: 'Synced from n8n'
          }
        }
      end

      it 'returns accepted status' do
        post url, params: payload.to_json, headers: oauth_headers

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('received')
        expect(json['data']['attributes']['event']).to eq('sync.community')
      end
    end

    context 'with an action event' do
      let(:payload) do
        {
          event: 'action.notify',
          payload: {
            message: 'Test notification'
          }
        }
      end

      it 'returns accepted status' do
        post url, params: payload.to_json, headers: oauth_headers

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('received')
      end
    end

    context 'with an unknown event type' do
      let(:payload) { { event: 'invalid.event_type' } }

      it 'returns unprocessable entity status' do
        post url, params: payload.to_json, headers: oauth_headers

        expect(response).to have_http_status(:unprocessable_content)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('unknown_event')
      end
    end

    context 'without an event parameter' do
      let(:payload) { { payload: { data: 'something' } } }

      it 'returns unprocessable entity with error message' do
        post url, params: payload.to_json, headers: oauth_headers

        expect(response).to have_http_status(:unprocessable_content)

        json = JSON.parse(response.body)
        expect(json['errors'].first['title']).to eq('Missing event type')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized status' do
        post url,
             params: { event: 'ping' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with JWT (not OAuth)' do
      let(:jwt_user) { create(:better_together_user, :confirmed) }
      let(:jwt_token) { api_sign_in_and_get_token(jwt_user) }

      it 'returns unauthorized status' do
        post url,
             params: { event: 'ping' }.to_json,
             headers: {
               'Authorization' => "Bearer #{jwt_token}",
               'Content-Type' => 'application/json',
               'Accept' => 'application/json'
             }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
