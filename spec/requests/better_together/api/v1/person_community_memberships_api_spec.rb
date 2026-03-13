# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::PersonCommunityMemberships', :no_auth do
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_person) { manager_user.person }
  let(:manager_token) { api_sign_in_and_get_token(manager_user) }
  let(:manager_headers) { api_auth_headers(manager_user, token: manager_token) }

  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_token) { api_sign_in_and_get_token(regular_user) }
  let(:regular_headers) { api_auth_headers(regular_user, token: regular_token) }

  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let(:community) { create(:better_together_community) }
  let(:role) { BetterTogether::Role.find_by(identifier: 'community_member') || create(:better_together_role) }

  describe 'GET /api/v1/person_community_memberships' do
    let(:url) { '/api/v1/person_community_memberships' }
    let!(:manager_membership) do
      create(:better_together_person_community_membership,
             member: manager_person, joinable: community, role: role)
    end
    let!(:other_membership) { create(:better_together_person_community_membership) }

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

      it 'returns all memberships' do
        json = JSON.parse(response.body)
        ids = json['data'].map { |m| m['id'] }

        expect(ids).to include(manager_membership.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/person_community_memberships/:id' do
    let!(:membership) do
      create(:better_together_person_community_membership,
             member: manager_person, joinable: community, role: role)
    end
    let(:url) { "/api/v1/person_community_memberships/#{membership.id}" }

    context 'when authenticated as platform manager' do
      before { get url, headers: manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']['id']).to eq(membership.id)
      end

      it 'returns membership attributes' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('status')
      end
    end
  end
end
