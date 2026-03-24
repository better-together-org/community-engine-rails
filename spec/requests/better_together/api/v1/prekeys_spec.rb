# frozen_string_literal: true

require 'rails_helper'

# Covers (member routes under resources :people — param is :id):
#   GET  /api/v1/people/:id/prekey_bundle         — existing endpoint
#   PUT  /api/v1/people/:id/register_prekeys      — existing endpoint
#   GET  /api/v1/people/:id/key_backup            — new: fetch encrypted backup blob
#   PUT  /api/v1/people/:id/key_backup            — new: store encrypted backup blob

RSpec.describe 'BetterTogether::Api::V1::Prekeys', :no_auth do
  let(:user)         { create(:better_together_user, :confirmed) }
  let(:person)       { user.person }
  let(:other_user)   { create(:better_together_user, :confirmed) }
  let(:other_person) { other_user.person }
  let(:token)        { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token, content_type: 'application/json') }

  # ── Valid test key material (base64-encoded, not real crypto) ──────────────

  let(:identity_key)     { Base64.strict_encode64('fake-identity-pub-32bytes--pad!') }
  let(:signed_pub_key)   { Base64.strict_encode64('fake-signed-pub-32bytes---pad!!') }
  let(:signature)        { Base64.strict_encode64("fake-sig-64bytes-#{'x' * 47}") }
  let(:otk_pub_key)      { Base64.strict_encode64('fake-otk-pub-32bytes------pad!') }

  let(:valid_register_params) do
    {
      registration_id: 12_345,
      identity_key: identity_key,
      signed_prekey: {
        id: 1,
        public_key: signed_pub_key,
        signature: signature
      },
      one_time_prekeys: [{ id: 1, public_key: otk_pub_key }]
    }
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  def register_prekeys_for(target_person, as_user: user)
    hdrs = api_auth_headers(as_user,
                            token: api_sign_in_and_get_token(as_user),
                            content_type: 'application/json')
    put "/api/v1/people/#{target_person.id}/register_prekeys",
        params: valid_register_params.to_json,
        headers: hdrs
  end

  # ── GET /key_backup ────────────────────────────────────────────────────────

  describe 'GET /api/v1/people/:person_id/key_backup' do
    let(:url) { "/api/v1/people/#{person.id}/key_backup" }

    context 'when no backup has been stored' do
      it 'returns 404' do
        get url, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        get url, headers: auth_headers
        expect(JSON.parse(response.body)).to include('error')
      end
    end

    context 'when a backup has been stored' do
      let(:blob) { Base64.strict_encode64("encrypted-blob-data#{'x' * 32}") }
      let(:salt) { Base64.strict_encode64('salt-16-bytes!!!') }

      before do
        person.update!(
          key_backup_blob: blob,
          key_backup_salt: salt,
          key_backup_updated_at: Time.current
        )
      end

      it 'returns 200' do
        get url, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns blob and salt' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json.dig('data', 'blob')).to eq(blob)
        expect(json.dig('data', 'salt')).to eq(salt)
      end

      it 'returns updated_at' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json.dig('data', 'updated_at')).to be_present
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as a different person' do
      let(:other_token)   { api_sign_in_and_get_token(other_user) }
      let(:other_headers) { api_auth_headers(other_user, token: other_token, content_type: 'application/json') }

      it 'returns forbidden' do
        get url, headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── PUT /key_backup ────────────────────────────────────────────────────────

  describe 'PUT /api/v1/people/:person_id/key_backup' do
    let(:url)  { "/api/v1/people/#{person.id}/key_backup" }
    let(:blob) { Base64.strict_encode64("encrypted-blob-#{'x' * 40}") }
    let(:salt) { Base64.strict_encode64('random-salt-16b!') }

    context 'with valid blob and salt' do
      before do
        put url, params: { blob: blob, salt: salt }.to_json, headers: auth_headers
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns status ok and updated_at' do
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['updated_at']).to be_present
      end

      it 'persists blob on the person record' do
        expect(person.reload.key_backup_blob).to eq(blob)
      end

      it 'persists salt on the person record' do
        expect(person.reload.key_backup_salt).to eq(salt)
      end

      it 'sets key_backup_updated_at' do
        expect(person.reload.key_backup_updated_at).to be_present
      end
    end

    context 'when blob is missing' do
      it 'returns unprocessable_entity' do
        put url, params: { salt: salt }.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when salt is missing' do
      it 'returns unprocessable_entity' do
        put url, params: { blob: blob }.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when blob is not valid base64' do
      it 'returns unprocessable_entity' do
        put url, params: { blob: 'not valid base64!!!', salt: salt }.to_json, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when overwriting an existing backup' do
      let(:new_blob)          { Base64.strict_encode64("newer-encrypted-blob-#{'x' * 35}") }
      let!(:existing_updated_at) do
        person.update!(key_backup_blob: blob, key_backup_salt: salt, key_backup_updated_at: 1.hour.ago)
        person.reload.key_backup_updated_at.iso8601(3)
      end

      before do
        put url,
            params: { blob: new_blob, salt: salt, previous_updated_at: existing_updated_at }.to_json,
            headers: auth_headers
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the blob' do
        expect(person.reload.key_backup_blob).to eq(new_blob)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        put url, params: { blob: blob, salt: salt }.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as a different person' do
      let(:other_token)   { api_sign_in_and_get_token(other_user) }
      let(:other_headers) { api_auth_headers(other_user, token: other_token, content_type: 'application/json') }

      it 'returns forbidden' do
        put url, params: { blob: blob, salt: salt }.to_json, headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not modify the person record' do
        put url, params: { blob: blob, salt: salt }.to_json, headers: other_headers
        expect(person.reload.key_backup_blob).to be_nil
      end
    end

    context 'with previous_updated_at (optimistic lock)' do
      it 'returns 200 when previous_updated_at matches current key_backup_updated_at' do
        # first write to establish a timestamp
        put url, params: { blob:, salt: }.to_json, headers: auth_headers
        updated_at = JSON.parse(response.body)['updated_at']

        put url, params: { blob:, salt:, previous_updated_at: updated_at }.to_json,
                 headers: auth_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns 409 when previous_updated_at is stale' do
        put url, params: { blob:, salt: }.to_json, headers: auth_headers

        put url,
            params: { blob:, salt:, previous_updated_at: '2000-01-01T00:00:00Z' }.to_json,
            headers: auth_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  # ── GET /prekey_bundle ─────────────────────────────────────────────────────

  describe 'GET /api/v1/people/:person_id/prekey_bundle' do
    let(:url) { "/api/v1/people/#{person.id}/prekey_bundle" }

    context 'when no prekeys registered' do
      it 'returns 404' do
        get url, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when prekeys are registered' do
      before { register_prekeys_for(person) }

      it 'returns 200' do
        get url, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end

      it 'includes identity_key in the bundle' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json.dig('data', 'identity_key')).to eq(identity_key)
      end

      it 'includes signed_prekey' do
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        expect(json.dig('data', 'signed_prekey', 'public_key')).to eq(signed_pub_key)
      end
    end

    context 'rate limiting' do
      it 'returns 429 after exceeding the per-requester limit' do
        limit = ENV.fetch('PREKEY_BUNDLE_REQUESTER_LIMIT', '20').to_i
        # Stub Rails.cache.increment so the requester counter exceeds the limit.
        # The controller calls increment for both the requester key and target key;
        # return limit+1 for every call so the requester check trips first.
        allow(Rails.cache).to receive(:increment).and_return(limit + 1)

        get url, headers: auth_headers
        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  # ── PUT /register_prekeys ──────────────────────────────────────────────────

  describe 'PUT /api/v1/people/:person_id/register_prekeys' do
    let(:url) { "/api/v1/people/#{person.id}/register_prekeys" }

    context 'with valid params' do
      before do
        put url, params: valid_register_params.to_json, headers: auth_headers
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns status ok' do
        expect(JSON.parse(response.body)['status']).to eq('ok')
      end

      it 'persists identity_key_public on the person' do
        expect(person.reload.identity_key_public).to eq(identity_key)
      end
    end

    context 'when missing required field' do
      it 'returns unprocessable_entity' do
        put url,
            params: valid_register_params.except(:identity_key).to_json,
            headers: auth_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when authenticated as a different person' do
      let(:other_token)   { api_sign_in_and_get_token(other_user) }
      let(:other_headers) { api_auth_headers(other_user, token: other_token, content_type: 'application/json') }

      it 'returns forbidden' do
        put url, params: valid_register_params.to_json, headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
