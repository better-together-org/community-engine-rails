# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::WebhookEndpoints', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/webhook_endpoints' do
    let(:url) { '/api/v1/webhook_endpoints' }

    context 'when authenticated as platform manager' do
      let!(:endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }

      before { get url, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'includes webhook endpoint data' do
        json = JSON.parse(response.body)
        endpoint_ids = json['data'].map { |e| e['id'] }

        expect(endpoint_ids).to include(endpoint.id)
      end

      it 'does not expose the secret in attributes' do
        json = JSON.parse(response.body)
        attributes = json['data'].first['attributes']

        expect(attributes).not_to have_key('secret')
      end
    end

    context 'when authenticated as regular user' do
      let!(:own_endpoint) { create(:better_together_webhook_endpoint, person: person) }
      let!(:other_endpoint) do
        create(:better_together_webhook_endpoint,
               person: create(:better_together_person))
      end

      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'only returns own endpoints' do
        json = JSON.parse(response.body)
        endpoint_ids = json['data'].map { |e| e['id'] }

        expect(endpoint_ids).to include(own_endpoint.id)
        expect(endpoint_ids).not_to include(other_endpoint.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/webhook_endpoints/:id' do
    let(:endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }
    let(:url) { "/api/v1/webhook_endpoints/#{endpoint.id}" }

    context 'when authenticated as platform manager' do
      before { get url, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted endpoint data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'webhook_endpoints',
          'id' => endpoint.id
        )
      end

      it 'includes endpoint attributes' do
        json = JSON.parse(response.body)
        attributes = json['data']['attributes']

        expect(attributes).to include(
          'name' => endpoint.name,
          'url' => endpoint.url,
          'active' => endpoint.active
        )
      end
    end
  end

  describe 'POST /api/v1/webhook_endpoints' do
    let(:url) { '/api/v1/webhook_endpoints' }
    let(:valid_params) do
      {
        data: {
          type: 'webhook_endpoints',
          attributes: {
            name: 'Test Webhook',
            url: 'https://example.com/webhooks',
            events: %w[community.created community.updated],
            active: true
          }
        }
      }
    end

    context 'when authenticated as platform manager' do
      it 'creates a new webhook endpoint' do
        expect do
          post url, params: valid_params.to_json, headers: platform_manager_headers
        end.to change(BetterTogether::WebhookEndpoint, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns the created endpoint data' do
        post url, params: valid_params.to_json, headers: platform_manager_headers

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['name']).to eq('Test Webhook')
        expect(json['data']['attributes']['url']).to eq('https://example.com/webhooks')
      end

      it 'auto-generates a secret' do
        post url, params: valid_params.to_json, headers: platform_manager_headers

        endpoint = BetterTogether::WebhookEndpoint.last
        expect(endpoint.secret).to be_present
      end
    end

    context 'with invalid data' do
      let(:invalid_params) do
        {
          data: {
            type: 'webhook_endpoints',
            attributes: {
              name: '',
              url: 'not-a-url'
            }
          }
        }
      end

      it 'returns unprocessable entity status' do
        post url, params: invalid_params.to_json, headers: platform_manager_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH /api/v1/webhook_endpoints/:id' do
    let(:endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }
    let(:url) { "/api/v1/webhook_endpoints/#{endpoint.id}" }
    let(:update_params) do
      {
        data: {
          type: 'webhook_endpoints',
          id: endpoint.id,
          attributes: {
            name: 'Updated Webhook Name'
          }
        }
      }
    end

    context 'when authenticated as platform manager' do
      it 'updates the endpoint' do
        patch url, params: update_params.to_json, headers: platform_manager_headers

        expect(response).to have_http_status(:ok)
        expect(endpoint.reload.name).to eq('Updated Webhook Name')
      end
    end
  end

  describe 'DELETE /api/v1/webhook_endpoints/:id' do
    let!(:endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }
    let(:url) { "/api/v1/webhook_endpoints/#{endpoint.id}" }

    context 'when authenticated as platform manager' do
      it 'destroys the endpoint' do
        expect do
          delete url, headers: platform_manager_headers
        end.to change(BetterTogether::WebhookEndpoint, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'POST /api/v1/webhook_endpoints/:id/test' do
    let(:endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }
    let(:url) { "/api/v1/webhook_endpoints/#{endpoint.id}/test" }

    context 'when authenticated as platform manager' do
      it 'creates a test delivery and returns accepted status' do
        expect do
          post url, headers: platform_manager_headers
        end.to change(BetterTogether::WebhookDelivery, :count).by(1)
                                                              .and have_enqueued_job(BetterTogether::WebhookDeliveryJob)

        expect(response).to have_http_status(:accepted)
      end

      it 'returns queued status in response' do
        post url, headers: platform_manager_headers

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('queued')
        expect(json['data']['attributes']['message']).to include('queued')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized status' do
        post url, headers: jsonapi_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
