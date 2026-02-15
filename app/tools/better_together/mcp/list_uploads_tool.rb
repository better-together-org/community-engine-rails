# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list user uploads
    # Scoped to creator's own uploads via policy
    class ListUploadsTool < ApplicationTool
      description 'List uploads owned by the current user'

      arguments do
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List uploads for the current user
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of upload objects
      def call(limit: 20)
        with_timezone_scope do
          uploads = fetch_uploads(limit)
          result = JSON.generate(uploads.map { |upload| serialize_upload(upload) })

          log_invocation('list_uploads', { limit: limit }, result.bytesize)
          result
        end
      end

      private

      def fetch_uploads(limit)
        policy_scope(BetterTogether::Upload)
          .limit([limit, 100].min)
      end

      def serialize_upload(upload)
        attrs = { id: upload.id, name: upload.name }
        attrs.merge!(file_attributes(upload))
        attrs.merge(created_at: upload.created_at.iso8601, updated_at: upload.updated_at.iso8601)
      end

      def file_attributes(upload)
        return {} unless upload.file.attached?

        { filename: upload.file.filename.to_s, content_type: upload.file.content_type,
          byte_size: upload.file.byte_size }
      end
    end
  end
end
