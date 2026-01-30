# frozen_string_literal: true

module BetterTogether
  # MCP Server instance accessor
  # @return [FastMcp::Server] The MCP server instance
  def self.mcp_server
    @mcp_server ||= begin
      server = FastMcp::Server.new(
        name: 'better-together',
        version: BetterTogether::VERSION
      )

      Rails.application.eager_load!

      # Auto-register all ApplicationTool descendants
      BetterTogether::Mcp::ApplicationTool.descendants.each do |tool_class|
        server.register_tool(tool_class)
      end

      BetterTogether::Mcp::ApplicationResource.descendants.each do |resource_class|
        server.register_resource(resource_class)
      end

      server
    end
  end
end
