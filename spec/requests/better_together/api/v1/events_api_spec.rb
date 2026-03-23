# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Events', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/events' do
    let(:url) { '/api/v1/events' }
    let!(:public_event) { create(:event, privacy: 'public') }
    let!(:private_event) { create(:event, privacy: 'private') }

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

      it 'includes public events in results' do
        json = JSON.parse(response.body)
        event_ids = json['data'].map { |e| e['id'] }

        expect(event_ids).to include(public_event.id)
      end
    end

    context 'when filtering by scope' do
      let!(:upcoming_event) { create(:event, :upcoming, privacy: 'public') }
      let!(:past_event) { create(:event, :past, privacy: 'public') }

      before { get url, params: { filter: { scope: 'upcoming' } }, headers: auth_headers }

      it 'returns filtered events' do
        json = JSON.parse(response.body)
        event_ids = json['data'].map { |e| e['id'] }

        expect(event_ids).to include(upcoming_event.id)
        expect(event_ids).not_to include(past_event.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/events/:id' do
    let(:test_event) { create(:event, privacy: 'public') }
    let(:url) { "/api/v1/events/#{test_event.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted event data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'events',
          'id' => test_event.id
        )
      end

      it 'includes event attributes' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to include(
          'name' => test_event.name,
          'privacy' => test_event.privacy,
          'timezone' => test_event.timezone
        )
      end

      it 'includes temporal attributes' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to have_key('starts_at')
        expect(json['data']['attributes']).to have_key('ends_at')
        expect(json['data']['attributes']).to have_key('local_starts_at')
        expect(json['data']['attributes']).to have_key('local_ends_at')
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/events' do
    let(:url) { '/api/v1/events' }
    let(:valid_params) do
      {
        data: {
          type: 'events',
          attributes: {
            name: 'Test Event',
            description: 'A test event for API',
            privacy: 'public',
            starts_at: 1.week.from_now.iso8601,
            ends_at: (1.week.from_now + 2.hours).iso8601,
            duration_minutes: 120,
            timezone: 'America/New_York'
          }
        }
      }
    end

    context 'when authenticated as platform manager' do
      before { post url, params: valid_params.to_json, headers: platform_manager_headers }

      it 'creates the event' do
        expect(response).to have_http_status(:created)
      end

      it 'returns the created event' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']['name']).to eq('Test Event')
        expect(json['data']['attributes']['privacy']).to eq('public')
      end
    end

    context 'when not authenticated' do
      before { post url, params: valid_params.to_json, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
