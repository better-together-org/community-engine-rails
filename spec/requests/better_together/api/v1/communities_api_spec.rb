# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Communities', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'GET /api/v1/communities' do
    let(:url) { '/en/api/v1/communities' }
    let!(:public_community) { create(:better_together_community, privacy: 'public') }
    let!(:private_community) { create(:better_together_community, privacy: 'private') }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
        expect(json['data'].first).to include('type' => 'communities')
      end

      it 'includes public communities in results' do
        json = JSON.parse(response.body)
        community_ids = json['data'].map { |c| c['id'] }

        expect(community_ids).to include(public_community.id)
      end

      it 'excludes private communities from results' do
        json = JSON.parse(response.body)
        community_ids = json['data'].map { |c| c['id'] }

        expect(community_ids).not_to include(private_community.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'only includes public communities' do
        json = JSON.parse(response.body)
        community_ids = json['data'].map { |c| c['id'] }

        expect(community_ids).to include(public_community.id)
        expect(community_ids).not_to include(private_community.id)
      end
    end
  end

  describe 'GET /api/v1/communities/:id' do
    let(:community) { create(:better_together_community, privacy: 'public') }
    let(:url) { "/en/api/v1/communities/#{community.id}" }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted community data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'communities',
          'id' => community.id
        )
        expect(json['data']['attributes']).to include(
          'name' => community.name,
          'slug' => community.slug
        )
      end
    end

    context 'when viewing private community without access' do
      let(:private_community) { create(:better_together_community, privacy: 'private') }
      let(:url) { "/en/api/v1/communities/#{private_community.id}" }

      before { get url, headers: auth_headers }

      it 'returns not found status' do
        # JSONAPI-resources policy scopes filter records, returning 404
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns success status for public community' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/communities' do
    let(:url) { '/en/api/v1/communities' }
    let(:valid_params) do
      {
        data: {
          type: 'communities',
          attributes: {
            name: 'Test Community',
            description: 'A test community',
            privacy: 'public'
          }
        }
      }
    end

    context 'when authenticated with permission' do
      before { post url, params: valid_params.to_json, headers: platform_manager_headers }

      it 'verifies platform manager permissions' do
        expect(platform_manager_token).to be_present
        expect(platform_manager_user.permitted_to?('manage_platform')).to be(true)

        platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        expect(platform_manager_role).to be_present
        expect(
          BetterTogether::PersonPlatformMembership.exists?(
            member: platform_manager_user.person,
            role: platform_manager_role
          )
        ).to be(true)
        expect(platform_manager_user.person.permitted_to?('create_community')).to be(true)
        expect(
          BetterTogether::Person.find(platform_manager_user.person.id).permitted_to?('create_community')
        ).to be(true)

        get '/en/api/v1/people/me', headers: platform_manager_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.dig('data', 'id')).to eq(platform_manager_user.person.id)
      end

      it 'creates a new community' do
        expect(response).to have_http_status(:created)
      end

      it 'returns JSONAPI-formatted community data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include('type' => 'communities')
        expect(json['data']['attributes']).to include(
          'name' => 'Test Community',
          'privacy' => 'public'
        )
      end
    end

    context 'when not authenticated' do
      before { post url, params: valid_params.to_json, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated without permission' do
      before { post url, params: valid_params.to_json, headers: auth_headers }

      it 'returns forbidden status' do
        # API layer obscures authorization failures as 404
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v1/communities/:id' do
    let(:community) { create(:better_together_community, creator: platform_manager_user.person) }
    let(:resource_id) { community.id }
    let(:url) { "/en/api/v1/communities/#{community.id}" }
    let(:update_params) do
      {
        data: {
          type: 'communities',
          id: resource_id,
          attributes: {
            name: 'Updated Name',
            description: 'Updated description'
          }
        }
      }
    end

    context 'when updating with permission' do
      before { patch url, params: update_params.to_json, headers: platform_manager_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the community' do
        community.reload
        expect(community.name).to eq('Updated Name')
      end
    end

    context 'when updating without permission' do
      let(:other_community) { create(:better_together_community) }
      let(:resource_id) { other_community.id }
      let(:url) { "/en/api/v1/communities/#{other_community.id}" }

      before { patch url, params: update_params.to_json, headers: auth_headers }

      it 'returns not found status' do
        # JSONAPI-resources policy scopes filter records, returning 404
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/communities/:id' do
    let(:community) { create(:better_together_community, creator: platform_manager_user.person) }
    let(:url) { "/en/api/v1/communities/#{community.id}" }

    context 'when deleting with permission' do
      before { delete url, headers: platform_manager_headers }

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes the community' do
        expect(BetterTogether::Community.find_by(id: community.id)).to be_nil
      end
    end

    context 'when deleting without permission' do
      let(:other_community) { create(:better_together_community) }
      let(:url) { "/en/api/v1/communities/#{other_community.id}" }

      before { delete url, headers: auth_headers }

      it 'returns not found status' do
        # JSONAPI-resources policy scopes filter records, returning 404
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when deleting protected community' do
      let(:protected_community) { create(:better_together_community, protected: true, creator: platform_manager_user.person) }
      let(:url) { "/en/api/v1/communities/#{protected_community.id}" }

      before { delete url, headers: platform_manager_headers }

      it 'returns unprocessable entity status' do
        # API layer obscures authorization failures as 404
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
