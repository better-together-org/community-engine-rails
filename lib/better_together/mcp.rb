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

      # Auto-register all ApplicationTool descendants
      Rails.application.config.after_initialize do
        BetterTogether::Mcp::ApplicationTool.descendants.each do |tool_class|
          server.register_tool(tool_class)
        end

        BetterTogether::Mcp::ApplicationResource.descendants.each do |resource_class|
          server.register_resource(resource_class)
        end
      end

      server
    end
  end
end
