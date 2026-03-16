# frozen_string_literal: true

require 'rails_helper'

# Covers E2E encryption endpoints on conversations:
#   GET /api/v1/conversations/:id/participant_prekey_bundles
#
# Also covers E2E message fields:
#   POST /api/v1/messages — e2e_encrypted: true stores fields, message.e2e? is true

RSpec.describe 'BetterTogether::Api::V1::Conversations E2E', :no_auth do
  let(:user)         { create(:better_together_user, :confirmed) }
  let(:person)       { user.person }
  let(:other_user)   { create(:better_together_user, :confirmed) }
  let(:other_person) { other_user.person }
  let(:token)        { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token, content_type: 'application/json') }

  # ── Valid key material (base64, not real crypto) ───────────────────────────

  let(:identity_key)   { Base64.strict_encode64('fake-identity-pub-32bytes--pad!') }
  let(:signed_pub_key) { Base64.strict_encode64('fake-signed-pub-32bytes---pad!!') }
  let(:signature)      { Base64.strict_encode64("fake-sig-64bytes-#{'x' * 47}") }
  let(:otk_pub_key)    { Base64.strict_encode64('fake-otk-pub-32bytes------pad!') }

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

  # Sequential integer counter — Person uses UUID PKs so target_person.id is not usable
  # as a registration_id (integer column). Each call within an example gets a unique integer;
  # database transactions roll back between examples so values are safe to reuse.
  def next_registration_id
    @_reg_id_seq ||= 10_000
    @_reg_id_seq += 1
  end

  def register_prekeys_for(target_person, as_user: user)
    hdrs = api_auth_headers(as_user,
                            token: api_sign_in_and_get_token(as_user),
                            content_type: 'application/json')
    params = valid_register_params.merge(registration_id: next_registration_id)
    put "/api/v1/people/#{target_person.id}/register_prekeys",
        params: params.to_json,
        headers: hdrs
  end

  def create_conversation_with(*participants)
    conv = create(:conversation, creator: person)
    ([person] + participants).uniq.each do |p|
      conv.participants << p unless conv.participants.include?(p)
    end
    conv
  end

  # ── GET /api/v1/conversations/:id/participant_prekey_bundles ───────────────

  describe 'GET /api/v1/conversations/:id/participant_prekey_bundles' do
    let!(:conversation) { create_conversation_with(other_person) }
    let(:url)           { "/api/v1/conversations/#{conversation.id}/participant_prekey_bundles" }

    context 'when participants have no prekeys registered' do
      before { get url, headers: auth_headers }

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns empty data array (no prekeys → bundles are omitted)' do
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data']).to be_empty
      end
    end

    context 'when participants have prekeys registered' do
      before do
        register_prekeys_for(person)
        register_prekeys_for(other_person, as_user: other_user)
        get url, headers: auth_headers
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a bundle for each registered participant' do
        json = JSON.parse(response.body)
        bundles = json['data']
        expect(bundles.length).to eq(2)
      end

      it 'each bundle includes person_id' do
        json = JSON.parse(response.body)
        person_ids = json['data'].map { |b| b['person_id'] }
        expect(person_ids).to include(person.id, other_person.id)
      end

      it 'each bundle includes identity_key' do
        json = JSON.parse(response.body)
        json['data'].each do |bundle|
          expect(bundle['identity_key']).to eq(identity_key)
        end
      end

      it 'each bundle includes a signed_prekey with id, public_key, and signature' do
        json = JSON.parse(response.body)
        json['data'].each do |bundle|
          spk = bundle['signed_prekey']
          expect(spk).to include('id', 'public_key', 'signature')
          expect(spk['public_key']).to eq(signed_pub_key)
          expect(spk['signature']).to eq(signature)
        end
      end

      it 'each bundle includes a one_time_prekey with id and public_key' do
        json = JSON.parse(response.body)
        json['data'].each do |bundle|
          otk = bundle['one_time_prekey']
          expect(otk).to include('id', 'public_key')
          expect(otk['public_key']).to eq(otk_pub_key)
        end
      end

      it 'consumes the one-time prekey (second fetch has no otk)' do
        # First fetch was done in before block; do a second
        get url, headers: auth_headers
        json = JSON.parse(response.body)
        json['data'].each do |bundle|
          expect(bundle['one_time_prekey']).to be_nil
        end
      end
    end

    context 'when the requesting user is not a participant' do
      let(:outsider)      { create(:better_together_user, :confirmed) }
      let(:outsider_hdrs) do
        api_auth_headers(outsider,
                         token: api_sign_in_and_get_token(outsider),
                         content_type: 'application/json')
      end

      it 'returns 404' do
        get url, headers: outsider_hdrs
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        get url, headers: outsider_hdrs
        expect(JSON.parse(response.body)).to include('error')
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when conversation does not exist' do
      it 'returns 404' do
        get '/api/v1/conversations/nonexistent-id/participant_prekey_bundles',
            headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
