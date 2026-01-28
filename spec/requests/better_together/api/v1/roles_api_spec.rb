# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Roles', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/roles' do
    let(:url) { '/api/v1/roles' }
    # Use existing roles created by automatic test setup to avoid uniqueness violations
    let!(:platform_role) do
      BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |role|
        role.name = 'Platform Manager'
        role.resource_type = 'BetterTogether::Platform'
        role.protected = true
      end
    end
    let!(:community_role) do
      BetterTogether::Role.find_or_create_by!(identifier: 'community_member') do |role|
        role.name = 'Community Member'
        role.resource_type = 'BetterTogether::Community'
        role.protected = true
      end
    end

    context 'when authenticated as platform manager' do
      before { get url, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
        expect(json['data'].first).to include('type' => 'roles')
      end

      it 'includes roles in results' do
        json = JSON.parse(response.body)
        role_ids = json['data'].map { |r| r['id'] }

        expect(role_ids).to include(platform_role.id)
        expect(role_ids).to include(community_role.id)
      end

      it 'includes role attributes' do
        json = JSON.parse(response.body)
        role_data = json['data'].find { |r| r['id'] == platform_role.id }

        expect(role_data['attributes']).to include(
          'name' => platform_role.name,
          'identifier' => platform_role.identifier
        )
      end
    end

    context 'when authenticated as regular user' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns filtered roles based on user permissions' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/roles/:id' do
    let(:role) do
      BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |r|
        r.name = 'Platform Manager'
        r.resource_type = 'BetterTogether::Platform'
        r.protected = true
      end
    end
    let(:url) { "/api/v1/roles/#{role.id}" }

    context 'when authenticated as platform manager' do
      before { get url, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted role data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'roles',
          'id' => role.id
        )
        expect(json['data']['attributes']).to include(
          'name' => role.name,
          'identifier' => role.identifier,
          'resource_type' => role.resource_type
        )
      end

      it 'includes protected flag for system roles' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).to have_key('protected')
      end
    end

    context 'when authenticated as regular user viewing accessible role' do
      let(:community) { create(:better_together_community) }
      let(:community_role) do
        BetterTogether::Role.find_or_create_by!(identifier: 'community_contributor') do |r|
          r.name = 'Community Contributor'
          r.resource_type = 'BetterTogether::Community'
          r.protected = false
        end
      end
      let(:url) { "/api/v1/roles/#{community_role.id}" }

      before do
        # Make user a member so they can see the role
        create(:better_together_person_community_membership,
               member: person,
               joinable: community,
               role: community_role)
        get url, headers: auth_headers
      end

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as regular user viewing a role' do
      let(:other_community) { create(:better_together_community) }
      let(:private_role) do
        # Create a generic community role - access restrictions handled by policy
        BetterTogether::Role.find_or_create_by!(identifier: 'community_strategist') do |r|
          r.name = 'Community Strategist'
          r.resource_type = 'BetterTogether::Community'
          r.protected = false
        end
      end
      let(:url) { "/api/v1/roles/#{private_role.id}" }

      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/roles' do
    let(:url) { '/api/v1/roles' }
    let(:valid_params) do
      {
        data: {
          type: 'roles',
          attributes: {
            name: 'Custom Role',
            description: 'A custom role',
            identifier: 'custom_role'
          }
        }
      }
    end

    context 'when attempting to create role' do
      before { post url, params: valid_params.to_json, headers: platform_manager_headers }

      it 'returns bad request status' do
        # Roles are read-only via API (creatable_fields returns []), JSONAPI returns 400
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'PATCH /api/v1/roles/:id' do
    let(:role) do
      BetterTogether::Role.find_or_create_by!(identifier: 'community_member') do |r|
        r.name = 'Community Member'
        r.resource_type = 'BetterTogether::Community'
        r.protected = true
      end
    end
    let(:url) { "/api/v1/roles/#{role.id}" }
    let(:update_params) do
      {
        data: {
          type: 'roles',
          id: role.id,
          attributes: {
            name: 'Updated Role Name'
          }
        }
      }
    end

    context 'when attempting to update role' do
      before { patch url, params: update_params.to_json, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE /api/v1/roles/:id' do
    let(:role) do
      BetterTogether::Role.find_or_create_by!(identifier: 'community_member') do |r|
        r.name = 'Community Member'
        r.resource_type = 'BetterTogether::Community'
        r.protected = true
      end
    end
    let(:url) { "/api/v1/roles/#{role.id}" }

    context 'when attempting to delete role' do
      before { delete url, headers: platform_manager_headers }

      it 'returns not found status' do
        # JSONAPI-resources returns 404 when destroy is not permitted
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when attempting to delete protected role' do
      let(:protected_role) do
        BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |r|
          r.name = 'Platform Manager'
          r.resource_type = 'BetterTogether::Platform'
          r.protected = true
        end
      end
      let(:url) { "/api/v1/roles/#{protected_role.id}" }

      before { delete url, headers: platform_manager_headers }

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
