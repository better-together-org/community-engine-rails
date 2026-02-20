# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Geography', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/geography_continents' do
    let(:url) { '/api/v1/geography_continents' }
    let!(:continent) { create(:better_together_geography_continent) }

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

      it 'includes continents' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(continent.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/geography_continents/:id' do
    let(:continent) { create(:better_together_geography_continent) }
    let(:url) { "/api/v1/geography_continents/#{continent.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the continent attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'geography_continents',
          'id' => continent.id
        )
        expect(json['data']['attributes']).to include('name')
      end
    end
  end

  describe 'GET /api/v1/geography_countries' do
    let(:url) { '/api/v1/geography_countries' }
    let!(:country) { create(:better_together_geography_country) }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes countries' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(country.id)
      end
    end
  end

  describe 'GET /api/v1/geography_countries/:id' do
    let(:country) { create(:better_together_geography_country) }
    let(:url) { "/api/v1/geography_countries/#{country.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns the country attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'geography_countries',
          'id' => country.id
        )
        expect(json['data']['attributes']).to include('name', 'iso_code')
      end
    end
  end

  describe 'GET /api/v1/geography_states' do
    let(:url) { '/api/v1/geography_states' }
    let!(:state) { create(:better_together_geography_state) }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes states' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(state.id)
      end
    end
  end

  describe 'GET /api/v1/geography_settlements' do
    let(:url) { '/api/v1/geography_settlements' }
    let!(:settlement) { create(:better_together_geography_settlement) }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes settlements' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(settlement.id)
      end
    end
  end
end
