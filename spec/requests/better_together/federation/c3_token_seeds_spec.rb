# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Federation::C3TokenSeeds', :no_auth do
  let(:source_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:peer_platform)   { create(:better_together_platform, :community_engine_peer) }
  let(:earner)          { create(:better_together_person, borgberry_did: "did:key:z6Mk#{SecureRandom.hex(16)}") }
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

  let(:valid_payload) do
    {
      c3_token_seed: {
        token_id: SecureRandom.uuid,
        earner_did: earner.borgberry_did,
        contribution_type: 'volunteer',
        c3_millitokens: 5_000,
        source_ref: SecureRandom.hex(32), # pre-hashed ref
        source_system: 'ce_joatu',
        emitted_at: Time.current.iso8601
      }
    }
  end

  before do
    source_platform.update!(host_url: 'https://primary.example.test', privacy: 'public', requires_invitation: false)
  end

  describe 'POST /federation/c3/token_seeds' do
    context 'with valid token and earner found' do
      it 'returns 201 applied: true and credits the earner' do
        expect do
          post better_together.c3_token_seed_path,
               params: valid_payload, headers: auth_headers, as: :json
        end.to change(BetterTogether::C3::TokenSeed, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['applied']).to be true
        expect(body['status']).to eq('ok')
      end
    end

    context 'when earner_did not found on this platform' do
      it 'returns 202 with reason earner_did_not_found_locally' do
        post better_together.c3_token_seed_path,
             params: valid_payload.deep_merge(c3_token_seed: { earner_did: 'did:key:zUnknown123' }),
             headers: auth_headers, as: :json

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body['applied']).to be false
        expect(body['reason']).to eq('earner_did_not_found_locally')
      end
    end

    context 'with a duplicate token_id' do
      it 'returns 200 and does not duplicate the applied transfer on second submission' do
        post better_together.c3_token_seed_path,
             params: valid_payload, headers: auth_headers, as: :json

        expect do
          post better_together.c3_token_seed_path,
               params: valid_payload, headers: auth_headers, as: :json
        end.not_to change(BetterTogether::C3::Token, :count)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('ok')
        expect(body['applied']).to be(true)
      end
    end

    context 'when the first submission is deferred' do
      let(:deferred_did) { "did:key:z6Mk#{SecureRandom.hex(16)}" }

      it 'replays the existing seed after the earner enrolls locally' do
        deferred_payload = valid_payload.deep_merge(c3_token_seed: { earner_did: deferred_did })

        expect do
          post better_together.c3_token_seed_path,
               params: deferred_payload, headers: auth_headers, as: :json
        end.to change(BetterTogether::C3::TokenSeed, :count).by(1)

        expect(response).to have_http_status(:accepted)

        create(:better_together_person, borgberry_did: deferred_did)

        expect do
          post better_together.c3_token_seed_path,
               params: deferred_payload, headers: auth_headers, as: :json
        end.to change(BetterTogether::C3::Token, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('ok')
        expect(body['applied']).to be(true)
      end
    end

    context 'without an auth token' do
      it 'returns 401' do
        post better_together.c3_token_seed_path, params: valid_payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a token missing c3.exchange scope' do
      it 'returns 401 unauthorized' do
        wrong_scope_token = BetterTogether::FederationAccessTokenIssuer.call(
          connection: connection,
          requested_scopes: 'content.feed.read'
        ).access_token

        post better_together.c3_token_seed_path,
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
        # Issue token with content.feed.read scope (only non-c3 scope available on this connection)
        non_c3_token = BetterTogether::FederationAccessTokenIssuer.call(
          connection: connection,
          requested_scopes: 'content.feed.read'
        ).access_token

        post better_together.c3_token_seed_path,
             params: valid_payload,
             headers: { 'Authorization' => "Bearer #{non_c3_token}" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with exchange rate applied' do
      before do
        connection.update!(c3_exchange_rate: '2.0')
      end

      it 'credits the earner with rate-adjusted millitokens' do
        earner_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: earner)
        before_millitokens = earner_balance.available_millitokens

        post better_together.c3_token_seed_path,
             params: valid_payload, headers: auth_headers, as: :json

        expect(response).to have_http_status(:created)
        # 5_000 millitokens * 2.0 rate = 10_000
        expect(earner_balance.reload.available_millitokens).to eq(before_millitokens + 10_000)
      end
    end
  end
end
