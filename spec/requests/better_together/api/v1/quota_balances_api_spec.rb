# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::QuotaBalances', :no_auth do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:auth_headers) { api_auth_headers(user) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let!(:own_balance) do
    BetterTogether::Quotas.settle!(
      type: 'media_storage', owner: person, amount: 500, idempotency_key: 'quota_balances_api_spec:own'
    )
    quota = BetterTogether::Quota.find_by(owner: person, quota_type: 'media_storage')
    BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative')
  end

  describe 'GET /api/v1/quota_balances' do
    let(:url) { '/api/v1/quota_balances' }

    context 'when not authenticated' do
      it 'returns unauthorized status' do
        get url, headers: jsonapi_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the owner' do
      it 'includes the caller\'s own balance' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_balance.id)
      end

      it 'exposes consumed and reserved' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        row = json['data'].find { |d| d['id'] == own_balance.id }
        expect(row['attributes']).to include('consumed' => 500, 'reserved' => 0)
      end
    end

    context 'when authenticated as an unrelated person' do
      it 'does not include another owner\'s balance' do
        other_headers = api_auth_headers(create(:better_together_user, :confirmed))
        get url, headers: other_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).not_to include(own_balance.id)
      end
    end

    context 'when authenticated as platform manager' do
      it 'includes every owner\'s balance' do
        get url, headers: platform_manager_headers
        json = JSON.parse(response.body)
        expect(json['data'].map { |d| d['id'] }).to include(own_balance.id)
      end
    end
  end
end
