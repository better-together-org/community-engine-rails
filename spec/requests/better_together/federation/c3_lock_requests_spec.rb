# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::C3LockRequests', :no_auth do
  let(:source_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:peer_platform)   { create(:better_together_platform, :community_engine_peer) }
  let(:payer)           { create(:better_together_person, borgberry_did: "did:key:z6Mk#{SecureRandom.hex(16)}") }
  let(:connection) do
    create(
      :better_together_platform_connection,
      :active,
      source_platform: peer_platform,
      target_platform: source_platform,
      federation_auth_policy: 'api_read',
      allow_identity_scope: true,
      allow_c3_exchange: true
    )
  end
  let(:token) do
    BetterTogether::FederationAccessTokenIssuer.call(
      connection: connection,
      requested_scopes: 'c3.exchange'
    ).access_token
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  let(:payer_balance) do
    BetterTogether::C3::Balance.find_or_create_by!(holder: payer).tap { |b| b.credit!(10.0) }
  end

  let(:valid_payload) do
    {
      c3_lock_request: {
        payer_did: payer.borgberry_did,
        c3_millitokens: 20_000,
        agreement_ref: "agreement:#{SecureRandom.uuid}"
      }
    }
  end

  before do
    source_platform.update!(host_url: 'https://primary.example.test', privacy: 'public', requires_invitation: false)
    payer_balance # ensure balance exists with funds
  end

  describe 'POST /federation/c3/lock_requests' do
    context 'with valid token and sufficient balance' do
      it 'returns 200 with lock_ref and decrements available balance' do
        expect do
          post better_together.c3_lock_request_path,
               params: valid_payload, headers: auth_headers, as: :json
        end.to change { payer_balance.reload.locked_millitokens }.by(20_000)
                                                                 .and change { payer_balance.reload.available_millitokens }.by(-20_000)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['locked']).to be true
        expect(body['lock_ref']).to match(/\A[0-9a-f-]{36}\z/)
      end

      it 'creates a BalanceLock record with the correct source_platform' do
        post better_together.c3_lock_request_path,
             params: valid_payload, headers: auth_headers, as: :json

        lock_ref = JSON.parse(response.body)['lock_ref']
        lock = BetterTogether::C3::BalanceLock.find_by!(lock_ref: lock_ref)
        expect(lock.source_platform).to eq(peer_platform)
        expect(lock.millitokens).to eq(20_000)
        expect(lock.status).to eq('pending')
      end
    end

    context 'with insufficient balance' do
      before { payer_balance.update!(available_millitokens: 0, lifetime_earned_millitokens: 0) }

      it 'returns 402 payment_required' do
        post better_together.c3_lock_request_path,
             params: valid_payload, headers: auth_headers, as: :json

        expect(response).to have_http_status(:payment_required)
        body = JSON.parse(response.body)
        expect(body['error']).to be_present
        expect(body['available_c3']).to eq(0.0)
      end
    end

    context 'when payer_did is not found' do
      it 'returns 422 with a generic error (no DID in body)' do
        post better_together.c3_lock_request_path,
             params: valid_payload.deep_merge(c3_lock_request: { payer_did: 'did:key:zUnknown' }),
             headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        # Must not expose the DID in the error body (enumeration prevention)
        expect(body['error']).not_to include('did:key:zUnknown')
      end
    end

    context 'without auth token' do
      it 'returns 401' do
        post better_together.c3_lock_request_path, params: valid_payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a token missing c3.exchange scope' do
      it 'returns 401 unauthorized' do
        wrong_scope_token = BetterTogether::FederationAccessTokenIssuer.call(
          connection: connection,
          requested_scopes: 'content.feed.read'
        ).access_token

        post better_together.c3_lock_request_path,
             params: valid_payload,
             headers: { 'Authorization' => "Bearer #{wrong_scope_token}" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when c3_exchange is not enabled on the connection' do
      let(:connection) do
        create(
          :better_together_platform_connection,
          :active,
          source_platform: peer_platform,
          target_platform: source_platform,
          federation_auth_policy: 'api_read',
          allow_identity_scope: true,
          allow_c3_exchange: false
        )
      end

      it 'returns 401 unauthorized' do
        non_c3_token = BetterTogether::FederationAccessTokenIssuer.call(
          connection: connection,
          requested_scopes: 'content.feed.read'
        ).access_token

        post better_together.c3_lock_request_path,
             params: valid_payload,
             headers: { 'Authorization' => "Bearer #{non_c3_token}" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
