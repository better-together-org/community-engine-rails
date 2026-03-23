# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Pages', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/pages' do
    let(:url) { '/api/v1/pages' }
    let!(:published_page) { create(:better_together_page, :published_public) }
    let!(:unpublished_page) { create(:better_together_page, :unpublished) }

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

      it 'includes published pages' do
        json = JSON.parse(response.body)
        page_ids = json['data'].map { |p| p['id'] }
        expect(page_ids).to include(published_page.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/pages/:id' do
    let(:page) { create(:better_together_page, :published_public) }
    let(:url) { "/api/v1/pages/#{page.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted page data' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'pages',
          'id' => page.id
        )
      end

      it 'includes page attributes' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']).to include(
          'title' => page.title,
          'slug' => page.slug,
          'privacy' => page.privacy
        )
      end
    end
  end
end
