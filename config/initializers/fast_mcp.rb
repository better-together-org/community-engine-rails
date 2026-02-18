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

# Rails 8 freezes the middleware stack earlier than Rails 7.
# Mounting FastMcp via `after_initialize` can raise FrozenError.
#
# This initializer mounts MCP during normal initialization, and derives
# its configuration directly from env vars to avoid initializer ordering
# issues (the engine sets `config.mcp` later).
if defined?(Rails)
  mcp_enabled = ENV.fetch('MCP_ENABLED', Rails.env.development?).to_s == 'true'

  skip_for_db_tasks = defined?(Rake) && Rake.application.top_level_tasks.any? { |t| t.start_with?('db:') }

  if mcp_enabled && !skip_for_db_tasks
    mcp_path_prefix = ENV.fetch('MCP_PATH_PREFIX', '/mcp')
    mcp_auth_token = ENV.fetch('MCP_AUTH_TOKEN', nil)
    mcp_authenticate = mcp_auth_token.present? || Rails.env.production?

    begin
      FastMcp.mount_in_rails( # rubocop:disable Metrics/BlockLength
        Rails.application,
        name: 'better-together',
        version: BetterTogether::VERSION,
        path_prefix: mcp_path_prefix,
        messages_route: 'messages',
        sse_route: 'sse',
        authenticate: mcp_authenticate,
        auth_token: mcp_auth_token,
        # Allow localhost connections in development
        localhost_only: Rails.env.development?,
        allowed_origins: Rails.env.development? ? ['localhost', '127.0.0.1'] : []
      ) do |server|
        # Filter tools based on user permissions
        server.filter_tools do |request, tools|
          context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)

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
          context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)

          # Platform managers can see all resources
          if context.permitted_to?('manage_platform')
            resources
          else
            # Regular users see resources without :admin tag
            resources.reject { |r| r.tags.include?(:admin) }
          end
        end
      end

      Rails.logger.info "MCP server initialized at #{mcp_path_prefix}"
    rescue FrozenError => e
      Rails.logger.warn("Skipping MCP mount because middleware stack is frozen: #{e.class}: #{e.message}")
    end

    # Register tools/resources after reload hooks are configured (and re-register
    # on each code reload in development) without modifying the middleware stack.
    Rails.application.config.to_prepare do
      next unless FastMcp.respond_to?(:server) && FastMcp.server

      require 'better_together/mcp'

      server = FastMcp.server

      server.tools.clear
      server.resources.clear

      BetterTogether::Mcp::ApplicationTool.descendants.each do |tool_class|
        server.register_tool(tool_class)
      end

      BetterTogether::Mcp::ApplicationResource.descendants.each do |resource_class|
        server.register_resource(resource_class)
      end
    end
  end
end
