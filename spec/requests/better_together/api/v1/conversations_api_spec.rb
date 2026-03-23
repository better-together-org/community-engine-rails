# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Conversations', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }
  let(:other_person) { create(:better_together_person) }

  describe 'GET /api/v1/conversations' do
    let(:url) { '/api/v1/conversations' }

    context 'when authenticated' do
      let!(:my_conversation) do
        conv = create(:conversation, creator: person)
        conv.participants << person unless conv.participants.include?(person)
        conv
      end
      let!(:other_conversation) { create(:conversation) }

      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns only user conversations' do
        json = JSON.parse(response.body)
        conv_ids = json['data'].map { |c| c['id'] }

        expect(conv_ids).to include(my_conversation.id)
        expect(conv_ids).not_to include(other_conversation.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/conversations/:id' do
    let!(:conversation) do
      conv = create(:conversation, creator: person)
      conv.participants << person unless conv.participants.include?(person)
      conv
    end
    let(:url) { "/api/v1/conversations/#{conversation.id}" }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns conversation data' do
        json = JSON.parse(response.body)

        expect(json['data']).to include(
          'type' => 'conversations',
          'id' => conversation.id
        )
      end
    end

    context 'when authenticated but not a participant' do
      let(:other_user) { create(:better_together_user, :confirmed) }
      let(:other_headers) { api_auth_headers(other_user) }
      let(:other_conversation) { create(:conversation) }
      let(:url) { "/api/v1/conversations/#{other_conversation.id}" }

      before { get url, headers: other_headers }

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
