# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Notifications', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/notifications' do
    let(:url) { '/api/v1/notifications' }

    before do
      # Create notifications for the current user's person
      create(:noticed_notification, recipient: person)
      create(:noticed_notification, recipient: person, read_at: Time.current)
    end

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

      it 'returns only user notifications' do
        json = JSON.parse(response.body)

        expect(json['data'].length).to eq(2)
      end
    end

    context 'when filtering by read status' do
      before { get url, params: { filter: { read: false } }, headers: auth_headers }

      it 'returns only unread notifications' do
        json = JSON.parse(response.body)

        json['data'].each do |notification|
          expect(notification['attributes']['is_read']).to be(false)
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

  describe 'POST /api/v1/notifications/mark_all_read' do
    let(:url) { '/api/v1/notifications/mark_all_read' }

    before do
      create_list(:noticed_notification, 3, recipient: person)
    end

    context 'when authenticated' do
      before { post url, headers: auth_headers }

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'marks all notifications as read' do
        unread_count = Noticed::Notification
                       .where(recipient: person, read_at: nil)
                       .count
        expect(unread_count).to eq(0)
      end
    end

    context 'when not authenticated' do
      before { post url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
