# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Fleet::Nodes', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:last_seen_at) { Time.current }
  let(:node_record) do
    Struct.new(:node_id, :hardware, :compute, :services, :last_seen_at, keyword_init: true) do
      def mark_online!; end

      def update!(*); end
    end.new(
      node_id: 'test-node-1',
      hardware: { 'ram_gb' => 32 },
      compute: { 'cpu' => 'm2' },
      services: { 'ollama' => true },
      last_seen_at:
    )
  end
  let(:node) { node_record }

  before do
    stub_const('BetterTogether::Fleet::Node', Class.new do
      def self.find_by(*)
        nil
      end
    end)
    allow(BetterTogether::Fleet::Node).to receive(:find_by).with(node_id: 'test-node-1').and_return(node)
    allow(node).to receive(:mark_online!)
    allow(node).to receive(:update!)
  end

  describe 'POST /api/v1/fleet/nodes/:node_id/heartbeat' do
    it 'accepts heartbeats that omit nested hardware, compute, or services payloads' do
      post "/api/v1/fleet/nodes/#{node.node_id}/heartbeat",
           params: {},
           headers: platform_manager_headers.merge('ACCEPT' => 'application/json')

      expect(response).to have_http_status(:ok)
      expect(node).to have_received(:update!).with(
        hardware: { 'ram_gb' => 32 },
        compute: { 'cpu' => 'm2' },
        services: { 'ollama' => true }
      )
    end
  end
end
