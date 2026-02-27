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

    # In development/test, allow connections from localhost and private network ranges
    # (covers Docker gateway, LAN hosts, and host-machine connections to containerised apps).
    # Enumerate the concrete IPs at boot rather than relying on subnet matching so that
    # the simple Array#include? check in FastMCP's valid_client_ip? works correctly.
    dev_allowed_ips = if Rails.env.development? || Rails.env.test?
                        require 'socket'
                        local_ips = Socket.ip_address_list
                                         .select { |a| a.ipv4? || a.ipv6_loopback? }
                                         .map(&:ip_address)
                        (FastMcp::Transports::RackTransport::DEFAULT_ALLOWED_IPS +
                          local_ips +
                          # Common Docker bridge / Compose network gateway IPs
                          %w[
                            0.0.0.0
                            172.17.0.1 172.18.0.1 172.19.0.1 172.20.0.1
                            172.21.0.1 172.22.0.1 172.23.0.1 172.24.0.1
                            192.168.0.1 192.168.1.1 10.0.0.1 10.45.20.100
                          ]).uniq
                      end

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
        # In development/test: allow localhost + common private/Docker IPs.
        # In production: keep localhost-only (restricted by default).
        localhost_only: !(Rails.env.development? || Rails.env.test?),
        allowed_ips: dev_allowed_ips || FastMcp::Transports::RackTransport::DEFAULT_ALLOWED_IPS,
        allowed_origins: Rails.env.development? ? ['localhost', '127.0.0.1', '0.0.0.0'] : []
      ) do |server|
        # Filter tools based on CE RBAC tier:
        #   :public        → visible to guests and authenticated users
        #   :authenticated → visible only to authenticated users
        #   :admin         → visible only to users with manage_platform permission
        # Tools with no tag default to :authenticated behaviour.
        server.filter_tools do |request, tools|
          context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)

          if context.permitted_to?('manage_platform')
            # Platform managers see all tools
            tools
          elsif context.authenticated?
            # Authenticated users see public + authenticated tools (not admin)
            tools.reject { |t| t.respond_to?(:tags) && t.tags.include?(:admin) }
          else
            # Guests see only tools explicitly tagged :public
            tools.select { |t| t.respond_to?(:tags) && t.tags.include?(:public) }
          end
        end

        # Filter resources: all resources are public-readable unless tagged :admin.
        # FastMCP::Resource does not implement .tags — use permission check only.
        server.filter_resources do |request, resources|
          context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)

          if context.permitted_to?('manage_platform')
            resources
          else
            # Exclude resource classes that define an :admin tag when the API is available
            resources.reject { |r| r.respond_to?(:tags) && r.tags.include?(:admin) }
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

      # Eager-load tool/resource classes so .descendants is populated in development
      # (Zeitwerk lazy-loads in development; descendants are empty until the files are required)
      [
        BetterTogether::Engine.root.join('app', 'tools'),
        BetterTogether::Engine.root.join('app', 'resources')
      ].each do |dir|
        Rails.autoloaders.main.eager_load_dir(dir.to_s) if dir.exist?
      end

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
