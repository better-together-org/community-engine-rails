# frozen_string_literal: true

module BetterTogether
  module Host
    # Renders the platform operations tools dashboard for platform managers.
    # Surfaces links and status information for Sidekiq, API docs, MCP, and OAuth.
    class OperationsController < ApplicationController
      def index
        authorize [:host_operations], :index?, policy_class: HostOperationsPolicy

        @mcp_enabled  = defined?(FastMcp) &&
                        ENV.fetch('MCP_ENABLED', Rails.env.development? ? 'true' : 'false') == 'true'
        @mcp_path     = ENV.fetch('MCP_PATH_PREFIX', '/mcp')
        @swagger_available = defined?(Rswag::Ui::Engine).present?
      end
    end
  end
end
