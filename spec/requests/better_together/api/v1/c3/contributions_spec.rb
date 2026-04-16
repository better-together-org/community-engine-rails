# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::C3::Contributions network_balance', :no_auth do
  let(:password) { 'SecureTest123!@#' }

  let(:earner) do
    create(:better_together_person, borgberry_did: "did:key:z6Mk#{SecureRandom.hex(16)}")
  end
  let(:other_person) do
    create(:better_together_person, borgberry_did: "did:key:z6Mk#{SecureRandom.hex(16)}")
  end

  # Regular user whose DID we query
  let(:earner_user) do
    create(:better_together_user, :confirmed,
           password: password, password_confirmation: password).tap do |u|
      u.update!(person: earner)
    end
  end
  let(:earner_token) { api_sign_in_and_get_token(earner_user, password: password) }
  let(:earner_headers) { { 'Authorization' => "Bearer #{earner_token}", 'Content-Type' => 'application/json' } }

  # Another user who should NOT be able to query the earner's balance
  let(:other_user) do
    create(:better_together_user, :confirmed,
           password: password, password_confirmation: password).tap do |u|
      u.update!(person: other_person)
    end
  end
  let(:other_token) { api_sign_in_and_get_token(other_user, password: password) }
  let(:other_headers) { { 'Authorization' => "Bearer #{other_token}", 'Content-Type' => 'application/json' } }

  # Platform manager (has administrator-level access)
  let(:admin_user) do
    create(:better_together_user, :confirmed, :platform_manager,
           password: password, password_confirmation: password)
  end
  let(:admin_token) { api_sign_in_and_get_token(admin_user, password: password) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{admin_token}", 'Content-Type' => 'application/json' } }

  let(:earner_balance) do
    BetterTogether::C3::Balance.find_or_create_by!(holder: earner).tap { |b| b.credit!(3.0) }
  end

  before { earner_balance }

  describe 'GET /api/v1/c3/network_balance' do
    let(:url) { '/api/v1/c3/network_balance' }

    context 'when querying your own DID' do
      it 'returns 200 with balance data' do
        get url, params: { borgberry_did: earner.borgberry_did }, headers: earner_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['borgberry_did']).to eq(earner.borgberry_did)
        expect(body['available_c3']).to be >= 0
      end
    end

    context 'when a platform admin queries another person\'s DID' do
      it 'returns 200' do
        get url, params: { borgberry_did: earner.borgberry_did }, headers: admin_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when querying someone else\'s DID as a regular user' do
      it 'returns 403 forbidden' do
        get url, params: { borgberry_did: earner.borgberry_did }, headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        get url, params: { borgberry_did: earner.borgberry_did }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
