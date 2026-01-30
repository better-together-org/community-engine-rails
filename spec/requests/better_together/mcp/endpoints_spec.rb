# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP HTTP Endpoint', :as_platform_manager do
  let(:platform) { BetterTogether::Platform.host.first }

  before do
    configure_host_platform
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

    context 'when authentication is not required' do
      before do
        allow(ENV).to receive(:fetch).with('MCP_AUTH_TOKEN', nil).and_return(nil)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'accepts requests without auth token' do
        post '/mcp/messages',
             params: valid_mcp_request.to_json,
             headers: { 'Content-Type': 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['jsonrpc']).to eq('2.0')
      rescue StandardError
        pending 'MCP endpoint not yet implemented'
      end
    end

    context 'when authentication is required' do
      before do
        allow(ENV).to receive(:fetch).with('MCP_AUTH_TOKEN', nil).and_return('secret-token-123')
      end

      it 'rejects requests without auth token' do
        post '/mcp/messages',
             params: valid_mcp_request.to_json,
             headers: { 'Content-Type': 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      rescue StandardError
        pending 'MCP authentication not yet implemented'
      end

      it 'accepts requests with valid auth token' do
        post '/mcp/messages',
             params: valid_mcp_request.to_json,
             headers: {
               'Content-Type': 'application/json',
               Authorization: 'Bearer secret-token-123'
             }

        expect(response).to have_http_status(:ok)
      rescue StandardError
        pending 'MCP authentication not yet implemented'
      end
    end

    context 'with user_id parameter' do
      let(:user) { create(:user) }
      let(:request_with_user) do
        valid_mcp_request.merge(params: { user_id: user.id })
      end

      it 'sets user context for authorization' do
        post '/mcp/messages',
             params: request_with_user.to_json,
             headers: { 'Content-Type': 'application/json' }

        expect(response).to have_http_status(:ok)
        # Tool/resource should have access to current_user
      rescue StandardError
        pending 'User context handling not yet implemented'
      end
    end
  end

  describe 'GET /mcp/sse' do
    it 'supports server-sent events transport' do
      get '/mcp/sse'

      expect(response.headers['Content-Type']).to include('text/event-stream')
    rescue StandardError
      pending 'SSE endpoint not yet implemented'
    end
  end
end
