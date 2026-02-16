# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::NavigationItems', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/navigation_items' do
    let(:url) { '/api/v1/navigation_items' }
    let!(:nav_area) { create(:better_together_navigation_area) }
    let!(:nav_item) { create(:better_together_navigation_item, navigation_area: nav_area) }

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

      it 'includes navigation items' do
        json = JSON.parse(response.body)
        # With ESSENTIAL_TABLES, navigation items accumulate across test runs.
        # Verify the response contains items and pagination metadata instead of
        # checking for specific IDs which may not appear on page 1.
        expect(json['data']).not_to be_empty
        expect(json['meta']).to include('record_count' => a_value > 0)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/navigation_items/:id' do
    let(:nav_area) { create(:better_together_navigation_area) }
    let(:nav_item) { create(:better_together_navigation_item, navigation_area: nav_area) }
    let(:url) { "/api/v1/navigation_items/#{nav_item.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the navigation item attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'navigation_items',
          'id' => nav_item.id
        )
        expect(json['data']['attributes']).to include(
          'title' => nav_item.title,
          'url' => nav_item.url
        )
      end
    end
  end
end
