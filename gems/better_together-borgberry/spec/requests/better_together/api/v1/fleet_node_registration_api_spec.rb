# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Fleet::Nodes registration', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_headers) do
    api_auth_headers(regular_user)
      .merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json')
  end
  let(:headers) do
    api_auth_headers(platform_manager_user, token: platform_manager_token)
      .merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json')
  end
  let(:service_application) do
    create(:better_together_oauth_application, :with_write_scope, :with_admin_scope, owner: platform_manager_user.person)
  end
  let(:service_token) do
    create(:better_together_oauth_access_token,
           :client_credentials,
           :with_write_scope,
           application: service_application,
           scopes: 'read write admin')
  end
  let(:service_headers) do
    {
      'Authorization' => "Bearer #{service_token.token}",
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json'
    }
  end
  let(:node_payload) do
    {
      node: {
        node_id: 'test-node-claim',
        node_category: 'cat1',
        safety_tier: 'T1',
        hardware: { ram_gb: 32 },
        compute: { cpu: 'm2' },
        services: { ollama: true }
      }
    }
  end

  describe 'POST /api/v1/fleet/nodes' do
    it 'assigns an unowned node to the authenticated operator by default' do
      post '/api/v1/fleet/nodes', params: node_payload.to_json, headers: headers

      expect(response).to have_http_status(:created)

      node = BetterTogether::Fleet::Node.find_by!(node_id: 'test-node-claim')
      expect(node.owner).to eq(platform_manager_user.person)

      body = JSON.parse(response.body)
      expect(body.dig('node', 'owner_type')).to eq('BetterTogether::Person')
      expect(body.dig('node', 'owner_id')).to eq(platform_manager_user.person.id)
    end

    it 'allows a platform manager to assign community ownership explicitly' do
      community = create(:better_together_community)

      post '/api/v1/fleet/nodes',
           params: node_payload.deep_merge(
             node: {
               node_id: 'test-community-node',
               owner_type: 'BetterTogether::Community',
               owner_id: community.id
             }
           ).to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(BetterTogether::Fleet::Node.find_by!(node_id: 'test-community-node').owner).to eq(community)
    end

    it 'allows a trusted OAuth service token to register a node' do
      post '/api/v1/fleet/nodes', params: node_payload.to_json, headers: service_headers

      expect(response).to have_http_status(:created)
      expect(BetterTogether::Fleet::Node.find_by!(node_id: 'test-node-claim').owner).to eq(platform_manager_user.person)
    end

    it 'rejects regular authenticated users' do
      post '/api/v1/fleet/nodes', params: node_payload.to_json, headers: regular_headers

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to include('error' => 'forbidden')
    end
  end
end
