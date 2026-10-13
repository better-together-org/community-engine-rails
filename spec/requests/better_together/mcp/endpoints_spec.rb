# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP HTTP Endpoints' do
  # MCP endpoints are served by FastMcp middleware, which is mounted in the test environment
  # (MCP_ENABLED defaults to true in development and test). These tests go through the middleware stack.

  it 'has the MCP middleware mounted' do
    expect(Rails.application.config.mcp.enabled).to be(true)
  end

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
      before { configure_host_platform }

      it 'accepts a JSON-RPC message (the reply is delivered over the SSE stream, so the body is empty)' do
        post '/mcp/messages',
             params: valid_mcp_request.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
      end
    end
  end

  describe 'Origin validation' do
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:body) { { jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} }.to_json }

    before do
      configure_host_platform
      BetterTogether::PlatformDomain.delete_all
      create(:better_together_platform_domain, platform: BetterTogether::Platform.find_by!(host: true),
                                               hostname: 'www.example.com')
      BetterTogether::Mcp::AllowedOrigins.reset_cache!
    end

    it 'accepts an Origin that is a platform domain' do
      post '/mcp/messages', params: body, headers: headers.merge('Origin' => 'https://www.example.com')

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a foreign Origin' do
      post '/mcp/messages', params: body, headers: headers.merge('Origin' => 'https://evil.example')

      expect(response).to have_http_status(:forbidden)
    end

    it 'accepts a request with no Origin to a platform domain host' do
      post '/mcp/messages', params: body, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a request to a host that is not a platform domain (DNS rebinding)' do
      host! 'rebound.evil.example'

      post '/mcp/messages', params: body, headers: headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'follows a platform domain being deactivated' do
      create(:better_together_platform_domain, platform: BetterTogether::Platform.find_by!(host: true),
                                               hostname: 'other.example.test').update!(active: false)

      post '/mcp/messages', params: body, headers: headers.merge('Origin' => 'https://other.example.test')

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /mcp/sse' do
    context 'when MCP middleware is mounted' do
      before { configure_host_platform }

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
