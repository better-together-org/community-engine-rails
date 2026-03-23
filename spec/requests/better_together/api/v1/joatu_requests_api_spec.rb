# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::JoatuRequests', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/joatu_requests' do
    let(:url) { '/api/v1/joatu_requests' }
    let!(:joatu_request) { create(:better_together_joatu_request, creator: person) }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'includes accessible requests' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(joatu_request.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/joatu_requests/:id' do
    let(:joatu_request) { create(:better_together_joatu_request, creator: person) }
    let(:url) { "/api/v1/joatu_requests/#{joatu_request.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the request attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'joatu_requests',
          'id' => joatu_request.id
        )
        expect(json['data']['attributes']).to include(
          'name' => joatu_request.name,
          'status' => joatu_request.status,
          'urgency' => joatu_request.urgency
        )
      end
    end
  end
end
