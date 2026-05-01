# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::JoatuAgreements', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let(:offer) { create(:better_together_joatu_offer, creator: person) }
  let(:request_record) { create(:better_together_joatu_request, creator: person) }

  describe 'GET /api/v1/joatu_agreements' do
    let(:url) { '/api/v1/joatu_agreements' }
    let!(:participant_private_agreement) do
      create(:better_together_joatu_agreement, privacy: 'private', offer: offer, request: request_record)
    end
    let!(:public_agreement) do
      create(:better_together_joatu_agreement, privacy: 'private').tap { |agreement_record| agreement_record.update_column(:privacy, 'public') }
    end
    let!(:other_private_agreement) { create(:better_together_joatu_agreement, privacy: 'private') }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'includes agreements where user is a participant' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |d| d['id'] }
        expect(ids).to include(participant_private_agreement.id, public_agreement.id)
        expect(ids).not_to include(other_private_agreement.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/joatu_agreements/:id' do
    let(:agreement) { create(:better_together_joatu_agreement, privacy: 'private', offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}" }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the agreement attributes' do
        json = JSON.parse(response.body)
        expect(json['data']).to include(
          'type' => 'joatu_agreements',
          'id' => agreement.id
        )
        expect(json['data']['attributes']).to include(
          'status' => agreement.status,
          'terms' => agreement.terms,
          'value' => agreement.value,
          'agreement_family' => agreement.agreement_family,
          'agreement_type' => agreement.agreement_type,
          'participant_ids' => match_array(agreement.participant_ids)
        )
      end
    end

    context 'when authenticated for a different private agreement' do
      let(:agreement) { create(:better_together_joatu_agreement, privacy: 'private') }

      before { get url, headers: auth_headers }

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/joatu_agreements/:id/accept' do
    let(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/accept" }

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'accepts the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('accepted')
        expect(json['data']['attributes']['decision_made_at']).to be_present
      end
    end

    context 'when not authenticated' do
      before { post url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/joatu_agreements/:id/reject' do
    let(:agreement) { create(:better_together_joatu_agreement, offer: offer, request: request_record) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/reject" }

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'rejects the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('rejected')
        expect(json['data']['attributes']['decision_made_at']).to be_present
      end
    end
  end

  describe 'POST /api/v1/joatu_agreements/:id/cancel' do
    let(:priced_offer) { create(:better_together_joatu_offer, creator: person, c3_price_millitokens: 20_000) }
    let(:other_user) { create(:better_together_user, :confirmed) }
    let(:other_request) { create(:better_together_joatu_request, creator: other_user.person) }
    let(:agreement) { create(:better_together_joatu_agreement, offer: priced_offer, request: other_request) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/cancel" }

    before do
      BetterTogether::C3::Balance.find_or_create_by!(holder: other_user.person).credit!(5.0)
      agreement.accept!
    end

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'cancels the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('cancelled')
        expect(json['data']['attributes']['decision_made_at']).to be_present
      end
    end
  end
end
