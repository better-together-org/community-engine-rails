# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::MembershipRequests', :no_auth do
  let(:jsonapi_headers) do
    { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' }
  end

  let(:community) { create(:better_together_community, :membership_requests_enabled) }

  let(:valid_payload) do
    {
      data: {
        type: 'membership_requests',
        attributes: {
          requestor_name: 'Alice Example',
          requestor_email: 'alice@example.test',
          referral_source: 'a friend',
          description: 'I would love to join the community and contribute.',
          target_type: 'BetterTogether::Community',
          target_id: community.id
        }
      }
    }.to_json
  end

  describe 'POST /api/v1/membership_requests' do
    let(:url) { '/api/v1/membership_requests' }

    it 'registers a dedicated Rack::Attack throttle for public submissions' do
      expect(Rack::Attack.throttles.keys).to include('api_membership_requests/ip')
    end

    context 'with valid unauthenticated request' do
      before { post url, params: valid_payload, headers: jsonapi_headers }

      it 'returns 201 created' do
        expect(response).to have_http_status(:created)
      end

      it 'returns JSONAPI-formatted membership request data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']['type']).to eq('membership_requests')
      end

      it 'stores the requestor_email' do
        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'requestor_email')).to eq('alice@example.test')
      end

      it 'persists the record in the database' do
        expect(BetterTogether::Joatu::MembershipRequest.count).to eq(1)
      end
    end

    context 'with missing requestor_email' do
      let(:invalid_payload) do
        {
          data: {
            type: 'membership_requests',
            attributes: {
              requestor_name: 'Bob Example',
              description: 'I would like to join.',
              target_type: 'BetterTogether::Community',
              target_id: community.id
            }
          }
        }.to_json
      end

      before { post url, params: invalid_payload, headers: jsonapi_headers }

      it 'returns 422 unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with invalid email format' do
      let(:bad_email_payload) do
        {
          data: {
            type: 'membership_requests',
            attributes: {
              requestor_name: 'Carol Example',
              requestor_email: 'not-valid',
              description: 'Please let me join.',
              target_type: 'BetterTogether::Community',
              target_id: community.id
            }
          }
        }.to_json
      end

      before { post url, params: bad_email_payload, headers: jsonapi_headers }

      it 'returns 422 unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with non-community target type' do
      let(:platform) { create(:better_together_platform) }
      let(:platform_payload) do
        {
          data: {
            type: 'membership_requests',
            attributes: {
              requestor_name: 'Dave Example',
              requestor_email: 'dave@example.test',
              description: 'Requesting platform membership.',
              target_type: 'BetterTogether::Platform',
              target_id: platform.id
            }
          }
        }.to_json
      end

      before { post url, params: platform_payload, headers: jsonapi_headers }

      it 'returns not found for an unsupported target type' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an authenticated user creating a request for another community' do
      let(:user) { create(:better_together_user, :confirmed) }
      let(:token) { api_sign_in_and_get_token(user) }
      let(:auth_headers) { api_auth_headers(user, token: token) }
      let(:authenticated_payload) do
        {
          data: {
            type: 'membership_requests',
            attributes: {
              description: 'I am an existing user requesting community membership.',
              target_type: 'BetterTogether::Community',
              target_id: community.id
            }
          }
        }.to_json
      end

      before { post url, params: authenticated_payload, headers: auth_headers }

      it 'returns 201 created' do
        expect(response).to have_http_status(:created)
      end

      it 'sets the creator to the authenticated person' do
        mr = BetterTogether::Joatu::MembershipRequest.last
        expect(mr.creator).to eq(user.person)
      end
    end
  end

  describe 'GET /api/v1/membership_requests (index)' do
    let(:url) { '/api/v1/membership_requests' }
    let!(:mr) { create(:better_together_joatu_membership_request) }

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as platform manager' do
      let(:manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
      let(:token) { api_sign_in_and_get_token(manager) }
      let(:auth_headers) { api_auth_headers(manager, token: token) }

      before { get url, headers: auth_headers }

      it 'returns success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
      end
    end
  end
end
