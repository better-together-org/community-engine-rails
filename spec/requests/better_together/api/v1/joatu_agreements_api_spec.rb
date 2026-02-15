# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::JoatuAgreements', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let(:offer) { create(:better_together_joatu_offer, creator: person) }
  let(:request_record) { create(:better_together_joatu_request, creator: person) }

  describe 'GET /api/v1/joatu_agreements' do
    let(:url) { '/api/v1/joatu_agreements' }
    let!(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'includes agreements where user is a participant' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(agreement.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/joatu_agreements/:id' do
    let(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}" }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the agreement attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'joatu_agreements',
          'id' => agreement.id
        )
        expect(json['data']['attributes']).to include(
          'status' => agreement.status,
          'terms' => agreement.terms,
          'value' => agreement.value
        )
      end
    end
  end

  describe 'POST /api/v1/joatu_agreements/:id/accept' do
    let(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/accept" }

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'accepts the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('accepted')
      end
    end

    context 'when not authenticated' do
      before { post url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/joatu_agreements/:id/reject' do
    let(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/reject" }

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'rejects the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('rejected')
      end
    end
  end
end
