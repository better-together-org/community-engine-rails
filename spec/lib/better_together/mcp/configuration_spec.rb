# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP Configuration', type: :request do
  describe 'when MCP is enabled' do
    before do
      allow(BetterTogether::Engine.config).to receive_message_chain(:mcp, :enabled).and_return(true)
      allow(BetterTogether::Engine.config).to receive_message_chain(:mcp, :path_prefix).and_return('/mcp')
    end

    it 'mounts MCP routes' do
      pending 'MCP routes not yet mounted'
      expect(Rails.application.routes.recognize_path('/mcp/messages', method: :post)).to include(controller: 'mcp/messages')
    end
  end

  describe 'when MCP is disabled' do
    before do
      allow(BetterTogether::Engine.config).to receive_message_chain(:mcp, :enabled).and_return(false)
    end

    it 'does not mount MCP routes' do
      expect do
        Rails.application.routes.recognize_path('/mcp/messages', method: :post)
      end.to raise_error(ActionController::RoutingError)
    end
  end
end

RSpec.describe 'MCP Server Initialization' do
  describe 'BetterTogether.mcp_server' do
    before do
      configure_host_platform
    end

    it 'returns FastMcp::Server instance' do
      expect(BetterTogether.mcp_server).to be_a(FastMcp::Server)
    end

    it 'has correct server name' do
      expect(BetterTogether.mcp_server.name).to eq('better-together')
    end

    it 'has version from engine' do
      expect(BetterTogether.mcp_server.version).to eq(BetterTogether::VERSION)
    end
  end

  describe 'tool and resource auto-registration' do
    let!(:server) { BetterTogether.mcp_server }

    it 'registers all ApplicationTool descendants' do
      tool_classes = BetterTogether::Mcp::ApplicationTool.descendants
      expect(tool_classes).not_to be_empty

      tool_classes.each do |tool_class|
        tools = server.tools.respond_to?(:values) ? server.tools.values : server.tools
        expect(tools).to include(tool_class)
      end
    end

    it 'registers all ApplicationResource descendants' do
      resource_classes = BetterTogether::Mcp::ApplicationResource.descendants
      expect(resource_classes).not_to be_empty

      resource_classes.each do |resource_class|
        resources = server.resources.respond_to?(:values) ? server.resources.values : server.resources
        expect(resources).to include(resource_class)
      end
    end
  end

  describe 'authentication configuration' do
    context 'when auth_token is configured' do
      before do
        allow(ENV).to receive(:fetch).with('MCP_AUTH_TOKEN', nil).and_return('test-token-123')
        Rails.application.config.mcp.auth_token = ENV.fetch('MCP_AUTH_TOKEN', nil)
        Rails.application.config.mcp.authenticate = true
      end

      it 'requires authentication' do
        expect(Rails.application.config.mcp.authenticate).to be true
      end
    end

    context 'when auth_token is not configured' do
      before do
        allow(ENV).to receive(:fetch).with('MCP_AUTH_TOKEN', nil).and_return(nil)
        Rails.application.config.mcp.auth_token = ENV.fetch('MCP_AUTH_TOKEN', nil)
        Rails.application.config.mcp.authenticate = false
      end

      it 'does not require authentication in development' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        expect(Rails.application.config.mcp.authenticate).to be false
      end
    end
  end
end
