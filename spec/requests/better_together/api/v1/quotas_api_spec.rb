# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Quotas', :no_auth do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let!(:own_quota) do
    BetterTogether::Quotas.settle!(
      type: 'media_storage', owner: person, amount: 500, idempotency_key: 'quotas_api_spec:own'
    )
    BetterTogether::Quota.find_by(owner: person, quota_type: 'media_storage')
  end

  describe 'GET /api/v1/quotas' do
    let(:url) { '/api/v1/quotas' }

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the owner' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes the caller\'s own quota' do
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_quota.id)
      end
    end

    context 'when authenticated as an unrelated person' do
      let(:other_user) { create(:better_together_user, :confirmed) }
      let(:other_headers) { api_auth_headers(other_user) }

      before { get url, headers: other_headers }

      it 'does not include another person\'s quota' do
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).not_to include(own_quota.id)
      end
    end

    context 'when authenticated as platform manager' do
      before { get url, headers: platform_manager_headers }

      it 'includes every owner\'s quota' do
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_quota.id)
      end
    end
  end

  describe 'GET /api/v1/quotas/:id' do
    let(:url) { "/api/v1/quotas/#{own_quota.id}" }

    context 'when authenticated as the owner' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes effective_limit alongside the stored limit' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']).to include('limit', 'effective_limit')
      end
    end

    context 'when authenticated as an unrelated person' do
      let(:other_user) { create(:better_together_user, :confirmed) }
      let(:other_headers) { api_auth_headers(other_user) }

      before { get url, headers: other_headers }

      it 'returns not found rather than revealing the record exists' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'write routes are not available' do
    it 'has no create route' do
      expect do
        post '/api/v1/quotas', params: {}.to_json, headers: platform_manager_headers
      end.to raise_error(ActionController::RoutingError, /No route matches/)
    end

    it 'has no update route' do
      expect do
        patch "/api/v1/quotas/#{own_quota.id}", params: {}.to_json, headers: platform_manager_headers
      end.to raise_error(ActionController::RoutingError, /No route matches/)
    end

    it 'has no destroy route' do
      expect do
        delete "/api/v1/quotas/#{own_quota.id}", headers: platform_manager_headers
      end.to raise_error(ActionController::RoutingError, /No route matches/)
    end
  end
end
