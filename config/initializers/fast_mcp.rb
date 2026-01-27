# frozen_string_literal: true

# Fast MCP initializer for Better Together Community Engine
#
# This file configures the Model Context Protocol (MCP) server for AI model integration
# while respecting platform privacy settings and Pundit authorization policies.
#
# Configuration via environment variables:
# - MCP_ENABLED: Enable/disable MCP endpoints (default: true in development)
# - MCP_AUTH_TOKEN: Authentication token for MCP requests (required in production)
# - MCP_PATH_PREFIX: URL path prefix for MCP endpoints (default: /mcp)
#
# See docs/implementation/mcp_integration_acceptance_criteria.md for details

Rails.application.config.after_initialize do
  # Skip if MCP not configured or disabled
  next unless Rails.application.config.respond_to?(:mcp) && Rails.application.config.mcp.enabled

  require 'better_together/mcp'

  # Mount MCP in Rails application
  FastMcp.mount_in_rails(
    Rails.application,
    name: 'better-together',
    version: BetterTogether::VERSION,
    path_prefix: Rails.application.config.mcp.path_prefix,
    messages_route: 'messages',
    sse_route: 'sse',
    authenticate: Rails.application.config.mcp.authenticate,
    auth_token: Rails.application.config.mcp.auth_token,
    # Allow localhost connections in development
    localhost_only: Rails.env.development?,
    allowed_origins: Rails.env.development? ? ['localhost', '127.0.0.1'] : []
  ) do |server|
    # Register all tools and resources
    BetterTogether::Mcp::ApplicationTool.descendants.each do |tool_class|
      server.register_tool(tool_class)
    end

    BetterTogether::Mcp::ApplicationResource.descendants.each do |resource_class|
      server.register_resource(resource_class)
    end

    # Filter tools based on user permissions
    server.filter_tools do |request, tools|
      context = BetterTogether::Mcp::PunditContext.from_request(request)

      # Platform managers can see all tools
      if context.permitted_to?('manage_platform')
        tools
      else
        # Regular users see tools without :admin tag
        tools.reject { |t| t.tags.include?(:admin) }
      end
    end

    # Filter resources based on user permissions
    server.filter_resources do |request, resources|
      context = BetterTogether::Mcp::PunditContext.from_request(request)

      # Platform managers can see all resources
      if context.permitted_to?('manage_platform')
        resources
      else
        # Regular users see resources without :admin tag
        resources.reject { |r| r.tags.include?(:admin) }
      end
    end
  end

  Rails.logger.info "MCP server initialized at #{Rails.application.config.mcp.path_prefix}"
end
