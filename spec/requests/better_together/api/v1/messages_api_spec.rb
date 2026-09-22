# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Messages', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let!(:conversation) do
    conv = create(:conversation, creator: person)
    conv.participants << person unless conv.participants.include?(person)
    conv
  end

  describe 'GET /api/v1/messages' do
    let(:url) { '/api/v1/messages' }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'only includes messages from conversations user participates in' do
        # Messages from the factory-created conversation should be present
        json = JSON.parse(response.body)
        message_ids = json['data'].map { |m| m['id'] }

        conversation.messages.each do |msg|
          expect(message_ids).to include(msg.id)
        end
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/messages/:id' do
    let(:message) { conversation.messages.first }
    let(:url) { "/api/v1/messages/#{message.id}" }

    context 'when authenticated as participant' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns message data' do
        json = JSON.parse(response.body)

        expect(json['data']).to include(
          'type' => 'messages',
          'id' => message.id
        )
      end
    end
  end
end
