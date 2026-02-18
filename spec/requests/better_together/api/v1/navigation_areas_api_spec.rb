# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::NavigationAreas', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/navigation_areas' do
    let(:url) { '/api/v1/navigation_areas' }
    let!(:nav_area) { create(:better_together_navigation_area, visible: true) }

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

      it 'includes navigation areas' do
        json = JSON.parse(response.body)
        area_ids = json['data'].map { |a| a['id'] }
        expect(area_ids).to include(nav_area.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/navigation_areas/:id' do
    let(:nav_area) { create(:better_together_navigation_area) }
    let(:url) { "/api/v1/navigation_areas/#{nav_area.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the navigation area attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'navigation_areas',
          'id' => nav_area.id
        )
        expect(json['data']['attributes']).to include(
          'name' => nav_area.name,
          'style' => nav_area.style
        )
      end
    end
  end
end
