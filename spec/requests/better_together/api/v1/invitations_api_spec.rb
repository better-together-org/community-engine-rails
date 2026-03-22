# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Invitations', :no_auth do
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_person) { manager_user.person }
  let(:manager_token) { api_sign_in_and_get_token(manager_user) }
  let(:manager_headers) { api_auth_headers(manager_user, token: manager_token) }

  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_token) { api_sign_in_and_get_token(regular_user) }
  let(:regular_headers) { api_auth_headers(regular_user, token: regular_token) }

  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/invitations' do
    let(:url) { '/api/v1/invitations' }
    let!(:own_invitation) do
      create(:better_together_invitation, inviter: manager_person)
    end
    let!(:other_invitation) { create(:better_together_invitation) }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'returns all invitations' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |i| i['id'] }

        expect(ids).to include(own_invitation.id, other_invitation.id)
      end
    end

    context 'when authenticated as regular user' do
      let!(:user_invitation) do
        create(:better_together_invitation, inviter: regular_user.person)
      end

      before { get url, headers: regular_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns only own invitations' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |i| i['id'] }

        expect(ids).to include(user_invitation.id)
        expect(ids).not_to include(other_invitation.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/invitations/:id' do
    let!(:invitation) { create(:better_together_invitation, inviter: manager_person) }
    let(:url) { "/api/v1/invitations/#{invitation.id}" }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']['id']).to eq(invitation.id)
      end

      it 'returns invitation attributes' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('status')
        expect(attrs).to have_key('invitee_email')
        expect(attrs).to have_key('locale')
      end
    end
  end

  describe 'GET /api/v1/invitations with status filter' do
    let(:url) { '/api/v1/invitations' }
    let!(:pending_invitation) do
      create(:better_together_invitation, inviter: manager_person, status: 'pending')
    end
    let!(:accepted_invitation) do
      create(:better_together_invitation, :accepted, inviter: manager_person)
    end

    context 'when filtering by status' do
      before { get "#{url}?filter[status]=pending", headers: manager_headers }

      it 'returns only matching invitations' do
        json = JSON.parse(response.body)
        statuses = json['data'].map { |i| i['attributes']['status'] }

        expect(statuses).to all(eq('pending'))
      end
    end
  end
end
