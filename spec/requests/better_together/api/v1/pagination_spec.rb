# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Pagination', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }

  describe 'GET /api/v1/webhook_endpoints with pagination' do
    let(:url) { '/api/v1/webhook_endpoints' }

    before do
      # Create 15 webhook endpoints to exceed the default page size
      15.times do
        create(:better_together_webhook_endpoint, person: platform_manager_user.person)
      end
    end

    it 'returns paginated results with page[number] and page[size]' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 1, 'page[size]' => 5 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(5)
    end

    it 'includes record_count in meta' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 1, 'page[size]' => 5 }

      json = JSON.parse(response.body)

      expect(json['meta']).to include('record_count')
      expect(json['meta']['record_count']).to eq(15)
    end

    it 'includes page_count in meta' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 1, 'page[size]' => 5 }

      json = JSON.parse(response.body)

      expect(json['meta']).to include('page_count')
      expect(json['meta']['page_count']).to eq(3)
    end

    it 'includes links for pagination navigation' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 2, 'page[size]' => 5 }

      json = JSON.parse(response.body)

      expect(json).to have_key('links')
      expect(json['links']).to include('first', 'last')
    end

    it 'returns the second page of results' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 2, 'page[size]' => 5 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(5)
    end

    it 'returns remaining records on the last page' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 3, 'page[size]' => 5 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(5)
    end

    it 'returns empty data for page beyond total pages' do
      get url, headers: platform_manager_headers, params: { 'page[number]' => 10, 'page[size]' => 5 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']).to be_empty
    end
  end

  describe 'GET /api/v1/posts with pagination' do
    let(:url) { '/api/v1/posts' }

    before do
      # Create public published posts using the factory defaults
      6.times do
        create(:better_together_post, privacy: 'public', published_at: 1.day.ago)
      end
    end

    it 'returns paginated results with correct page size' do
      get url, headers: platform_manager_headers, params: { 'page[size]' => 4 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data'].length).to eq(4)
      expect(json['meta']['record_count']).to be >= 6
    end
  end
end
