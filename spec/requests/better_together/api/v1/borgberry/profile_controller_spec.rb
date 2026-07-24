# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Borgberry::Profile', :no_auth do
  let(:user)    { create(:better_together_user, :confirmed) }
  let(:token)   { api_sign_in_and_get_token(user) }
  let(:headers) do
    api_auth_headers(user, token: token)
      .merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json')
  end

  describe 'GET /api/v1/borgberry/profile' do
    context 'when authenticated and borgberry_did is set' do
      let(:did) { 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK' }

      before { user.person.update!(borgberry_did: did) }

      it 'returns HTTP 200' do
        get '/api/v1/borgberry/profile', headers: headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns borgberry_did in the response body' do
        get '/api/v1/borgberry/profile', headers: headers
        json = JSON.parse(response.body)
        expect(json['borgberry_did']).to eq(did)
      end

      it 'returns person_id in the response body' do
        get '/api/v1/borgberry/profile', headers: headers
        json = JSON.parse(response.body)
        expect(json['person_id']).to eq(user.person.id)
      end
    end

    context 'when authenticated but borgberry_did is not set' do
      before { user.person.update!(borgberry_did: nil) }

      it 'returns HTTP 422 unprocessable_entity' do
        get '/api/v1/borgberry/profile', headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error message indicating the DID is not set' do
        get '/api/v1/borgberry/profile', headers: headers
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
        expect(json['error']).to match(/borgberry_did not set/i)
      end
    end

    context 'when unauthenticated' do
      it 'returns HTTP 401 unauthorized' do
        get '/api/v1/borgberry/profile',
            headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
