# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP HTTP Endpoints' do
  # MCP endpoints are served by FastMcp middleware, which is only mounted when
  # MCP_ENABLED=true (defaults to false in test environment). These tests verify
  # endpoint behavior by testing through the middleware stack directly.

  let(:mcp_enabled) { Rails.application.config.respond_to?(:mcp) && Rails.application.config.mcp.enabled }

  describe 'POST /mcp/messages' do
    let(:valid_mcp_request) do
      {
        jsonrpc: '2.0',
        id: 1,
        method: 'tools/list',
        params: {}
      }
    end

    context 'when MCP middleware is mounted' do
      before do
        skip 'MCP middleware not mounted in test environment (set MCP_ENABLED=true to test)' unless mcp_enabled
        configure_host_platform
      end

      it 'responds with JSON-RPC format' do
        post '/mcp/messages',
             params: valid_mcp_request.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['jsonrpc']).to eq('2.0')
      end
    end

    context 'when MCP middleware is not mounted' do
      before do
        skip 'MCP middleware is mounted; skipping not-mounted test' if mcp_enabled
      end

      it 'returns routing error for MCP paths' do
        expect do
          post '/mcp/messages',
               params: valid_mcp_request.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end.to raise_error(ActionController::RoutingError)
      end
    end
  end

  describe 'GET /mcp/sse' do
    context 'when MCP middleware is mounted' do
      before do
        skip 'MCP middleware not mounted in test environment (set MCP_ENABLED=true to test)' unless mcp_enabled
        configure_host_platform
      end

      it 'responds with event-stream content type' do
        get '/mcp/sse'

        expect(response.headers['Content-Type']).to include('text/event-stream')
      end
    end
  end

  describe 'authentication security' do
    let(:user) { create(:user) }

    before do
      configure_host_platform
    end

    it 'does NOT trust user_id from request params' do
      request = instance_double(
        Rack::Request,
        env: { 'warden' => nil },
        params: { 'user_id' => user.id }
      )
      allow(request).to receive(:respond_to?).with(:env).and_return(true)

      context = BetterTogether::Mcp::PunditContext.from_request(request)

      # Even though user_id is in params, it should NOT be used
      expect(context.user).to be_nil
    end

    it 'resolves user from Warden session' do
      warden = instance_double(Warden::Proxy, user: user)
      request = instance_double(
        Rack::Request,
        env: { 'warden' => warden }
      )
      allow(request).to receive(:respond_to?).with(:env).and_return(true)

      context = BetterTogether::Mcp::PunditContext.from_request(request)

      expect(context.user).to eq(user)
    end

    it 'returns anonymous context when no Warden session' do
      request = instance_double(
        Rack::Request,
        env: {}
      )
      allow(request).to receive(:respond_to?).with(:env).and_return(true)

      context = BetterTogether::Mcp::PunditContext.from_request(request)

      expect(context.user).to be_nil
    end
  end
end
