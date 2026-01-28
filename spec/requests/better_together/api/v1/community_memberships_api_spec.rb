# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::PersonCommunityMemberships', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  let(:community) { create(:better_together_community) }
  let(:organizer_role) { create(:better_together_role, :community_role) }
  let(:member_role) { create(:better_together_role, :community_role) }

  describe 'GET /api/v1/person_community_memberships' do
    let(:url) { '/api/v1/person_community_memberships' }
    let!(:user_membership) do
      create(:better_together_person_community_membership,
             member: person,
             joinable: community,
             role: member_role)
    end
    let!(:other_membership) do
      create(:better_together_person_community_membership,
             joinable: community,
             role: member_role)
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
        expect(json['data'].first).to include('type' => 'person_community_memberships')
      end

      it 'includes own membership in results' do
        json = JSON.parse(response.body)
        membership_ids = json['data'].map { |m| m['id'] }

        expect(membership_ids).to include(user_membership.id)
      end

      it 'does not include memberships from joined communities' do
        json = JSON.parse(response.body)
        membership_ids = json['data'].map { |m| m['id'] }

        # Scope limits visibility to own memberships
        expect(membership_ids).not_to include(other_membership.id)
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
    let(:membership) do
      create(:better_together_person_community_membership,
             member: person,
             joinable: community,
             role: member_role)
    end
    let(:url) { "/api/v1/person_community_memberships/#{membership.id}" }

    context 'when viewing own membership' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted membership data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'person_community_memberships',
          'id' => membership.id
        )
        expect(json['data']['attributes']).to include('status' => membership.status)
      end
    end

    context 'when viewing membership without access' do
      let(:other_community) { create(:better_together_community) }
      let(:other_membership) do
        create(:better_together_person_community_membership,
               joinable: other_community,
               role: create(:better_together_role, :community_role))
      end
      let(:url) { "/api/v1/person_community_memberships/#{other_membership.id}" }

      before { get url, headers: auth_headers }

      it 'returns not found status' do
        # Policy scope limits membership visibility to own memberships
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/person_community_memberships' do
    let(:url) { '/api/v1/person_community_memberships' }
    let(:new_person) { create(:better_together_person) }
    let(:valid_params) do
      {
        data: {
          type: 'person_community_memberships',
          attributes: {
            status: 'active'
          },
          relationships: {
            member: {
              data: { type: 'people', id: new_person.id }
            },
            joinable: {
              data: { type: 'communities', id: community.id }
            },
            role: {
              data: { type: 'roles', id: member_role.id }
            }
          }
        }
      }
    end

    context 'when platform manager creates membership' do
      before { post url, params: valid_params.to_json, headers: platform_manager_headers }

      it 'creates a new membership' do
        expect(response).to have_http_status(:created)
      end

      it 'returns JSONAPI-formatted membership data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include('type' => 'person_community_memberships')
        expect(json['data']['attributes']).to include('status' => 'active')
      end
    end

    context 'when regular user creates membership without permission' do
      before { post url, params: valid_params.to_json, headers: auth_headers }

      it 'returns not found status' do
        # Authorization failures are obscured as 404
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { post url, params: valid_params.to_json, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/person_community_memberships/:id' do
    let(:membership) do
      create(:better_together_person_community_membership,
             member: create(:better_together_person),
             joinable: community,
             role: member_role,
             status: 'pending')
    end
    let(:url) { "/api/v1/person_community_memberships/#{membership.id}" }
    let(:update_params) do
      {
        data: {
          type: 'person_community_memberships',
          id: membership.id,
          attributes: {
            status: 'active'
          }
        }
      }
    end

    context 'when platform manager updates membership' do
      before { patch url, params: update_params.to_json, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the membership' do
        membership.reload
        expect(membership.status).to eq('active')
      end
    end

    context 'when regular user updates membership without permission' do
      before { patch url, params: update_params.to_json, headers: auth_headers }

      it 'returns not found status' do
        # JSONAPI-resources policy scopes filter records, returning 404
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { patch url, params: update_params.to_json, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/person_community_memberships/:id' do
    let(:membership) do
      create(:better_together_person_community_membership,
             member: person,
             joinable: community,
             role: member_role)
    end
    let(:url) { "/api/v1/person_community_memberships/#{membership.id}" }

    context 'when user leaves own community' do
      before { delete url, headers: auth_headers }

      it 'returns not found status' do
        # Authorization failures are obscured as 404
        expect(response).to have_http_status(:not_found)
      end

      it 'does not delete the membership' do
        expect(BetterTogether::PersonCommunityMembership.find_by(id: membership.id)).to be_present
      end
    end

    context 'when platform manager removes membership' do
      let(:other_membership) do
        create(:better_together_person_community_membership,
               joinable: community,
               role: member_role)
      end
      let(:url) { "/api/v1/person_community_memberships/#{other_membership.id}" }

      before { delete url, headers: platform_manager_headers }

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes the membership' do
        expect(BetterTogether::PersonCommunityMembership.find_by(id: other_membership.id)).to be_nil
      end
    end

    context 'when deleting membership without permission' do
      let(:other_membership) do
        create(:better_together_person_community_membership,
               joinable: community,
               role: member_role)
      end
      let(:url) { "/api/v1/person_community_memberships/#{other_membership.id}" }

      before { delete url, headers: auth_headers }

      it 'returns not found status' do
        # JSONAPI-resources policy scopes filter records, returning 404
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { delete url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
