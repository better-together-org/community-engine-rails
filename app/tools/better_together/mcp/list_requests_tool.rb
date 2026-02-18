# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list Joatu requests
    # Respects Joatu exchange policies and response link visibility
    class ListRequestsTool < ApplicationTool
      description 'List open Joatu requests (things people need fulfilled)'

      arguments do
        optional(:status)
          .filled(:string)
          .description('Filter by status: open, matched, fulfilled, closed')
        optional(:urgency)
          .filled(:string)
          .description('Filter by urgency: low, normal, high, critical')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List requests accessible to the current user
      # @param status [String] Optional status filter
      # @param urgency [String] Optional urgency filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of request objects
      def call(status: nil, urgency: nil, limit: 20)
        with_timezone_scope do
          requests = fetch_requests(status, urgency, limit)
          result = JSON.generate(requests.map { |req| serialize_request(req) })

          log_invocation('list_requests', { status: status, urgency: urgency, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def fetch_requests(status, urgency, limit)
        scope = policy_scope(BetterTogether::Joatu::Request)
        scope = scope.where(status: status) if status.present?
        scope = scope.where(urgency: urgency) if urgency.present?
        scope.order(created_at: :desc).limit([limit, 100].min)
      end

      def serialize_request(req)
        {
          id: req.id,
          name: req.name,
          status: req.status,
          urgency: req.urgency,
          slug: req.slug,
          creator_id: req.creator_id,
          created_at: req.created_at.iso8601,
          updated_at: req.updated_at.iso8601
        }
      end
    end
  end
end
