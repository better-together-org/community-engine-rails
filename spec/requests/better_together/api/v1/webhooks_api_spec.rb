# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Webhooks', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) do
    {
      'Authorization' => "Bearer #{platform_manager_token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  describe 'POST /api/v1/webhooks/receive' do
    let(:url) { '/api/v1/webhooks/receive' }

    context 'with a ping event' do
      let(:payload) { { event: 'ping' } }

      it 'returns pong response' do
        post url, params: payload.to_json, headers: platform_manager_headers

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
        post url, params: payload.to_json, headers: platform_manager_headers

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
        post url, params: payload.to_json, headers: platform_manager_headers

        expect(response).to have_http_status(:accepted)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('received')
      end
    end

    context 'with an unknown event type' do
      let(:payload) { { event: 'invalid.event_type' } }

      it 'returns unprocessable entity status' do
        post url, params: payload.to_json, headers: platform_manager_headers

        expect(response).to have_http_status(:unprocessable_content)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('unknown_event')
      end
    end

    context 'without an event parameter' do
      let(:payload) { { payload: { data: 'something' } } }

      it 'returns unprocessable entity with error message' do
        post url, params: payload.to_json, headers: platform_manager_headers

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
  end
end
