# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Posts', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/posts' do
    let(:url) { '/api/v1/posts' }
    let!(:published_post) { create(:better_together_post, privacy: 'public', published_at: 1.day.ago) }

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
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/posts/:id' do
    let(:test_post) { create(:better_together_post, privacy: 'public', published_at: 1.day.ago) }
    let(:url) { "/api/v1/posts/#{test_post.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted post data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'posts',
          'id' => test_post.id
        )
      end

      it 'includes post attributes' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to have_key('title')
        expect(json['data']['attributes']).to have_key('slug')
        expect(json['data']['attributes']).to have_key('privacy')
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/posts' do
    let(:url) { '/api/v1/posts' }
    let(:valid_params) do
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'Test Post',
            content: 'Test content for the API post',
            privacy: 'public'
          }
        }
      }
    end

    context 'when authenticated as platform manager' do
      before { post url, params: valid_params.to_json, headers: platform_manager_headers }

      it 'creates the post' do
        expect(response).to have_http_status(:created)
      end

      it 'returns the created post' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']['title']).to eq('Test Post')
      end
    end

    context 'when authenticated as regular user' do
      before { post url, params: valid_params.to_json, headers: auth_headers }

      it 'denies creation' do
        # PostPolicy requires manage_platform for create
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { post url, params: valid_params.to_json, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
