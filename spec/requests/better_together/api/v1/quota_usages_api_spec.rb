# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::QuotaUsages', :no_auth do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:auth_headers) { api_auth_headers(user) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let!(:own_usage) do
    BetterTogether::Quotas.settle!(
      type: 'media_storage', owner: person, amount: 500, idempotency_key: 'quota_usages_api_spec:own'
    )
  end

  describe 'GET /api/v1/quota_usages' do
    let(:url) { '/api/v1/quota_usages' }

    context 'when not authenticated' do
      it 'returns unauthorized status' do
        get url, headers: jsonapi_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the owner' do
      it 'includes the caller\'s own usage row' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_usage.id)
      end
    end

    context 'when authenticated as an unrelated person' do
      it 'does not include another person\'s usage row' do
        other_headers = api_auth_headers(create(:better_together_user, :confirmed))
        get url, headers: other_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).not_to include(own_usage.id)
      end
    end

    context 'when authenticated as platform manager' do
      it 'includes every owner\'s usage row' do
        get url, headers: platform_manager_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_usage.id)
      end
    end
  end

  describe 'write routes are not available' do
    it 'has no create route' do
      expect do
        post '/api/v1/quota_usages', params: {}.to_json, headers: platform_manager_headers
      end.to raise_error(ActionController::RoutingError, /No route matches/)
    end
  end
end
