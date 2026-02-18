# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Uploads', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/uploads' do
    let(:url) { '/api/v1/uploads' }
    let!(:my_upload) { create(:better_together_upload, creator: person) }
    let!(:other_upload) { create(:better_together_upload, creator: create(:better_together_person)) }

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

      it 'only includes own uploads (scoped by policy)' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(my_upload.id)
        expect(ids).not_to include(other_upload.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/uploads/:id' do
    let(:upload) { create(:better_together_upload, creator: person) }
    let(:url) { "/api/v1/uploads/#{upload.id}" }

    context 'when authenticated as owner' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the upload attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'uploads',
          'id' => upload.id
        )
        expect(json['data']['attributes']).to include('name')
      end
    end
  end
end
