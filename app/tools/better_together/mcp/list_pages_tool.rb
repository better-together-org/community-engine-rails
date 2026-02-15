# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list published pages
    # Respects privacy settings and publication status
    class ListPagesTool < ApplicationTool
      description 'List published pages with titles and content excerpts'

      arguments do
        optional(:privacy)
          .filled(:string)
          .description('Filter by privacy level: public or private')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List pages accessible to the current user
      # @param privacy [String] Optional privacy filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of page objects
      def call(privacy: nil, limit: 20)
        with_timezone_scope do
          pages = fetch_pages(privacy, limit)
          result = JSON.generate(pages.map { |page| serialize_page(page) })

          log_invocation('list_pages', { privacy: privacy, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def fetch_pages(privacy, limit)
        scope = policy_scope(BetterTogether::Page)
        scope = scope.where(privacy: privacy) if privacy.present?
        scope.order(published_at: :desc).limit([limit, 100].min)
      end

      def serialize_page(page)
        {
          id: page.id,
          title: page.title,
          slug: page.slug,
          privacy: page.privacy,
          layout: page.layout,
          published_at: page.published_at&.iso8601,
          content_excerpt: page.content&.to_plain_text&.truncate(200),
          created_at: page.created_at.iso8601,
          updated_at: page.updated_at.iso8601
        }
      end
    end
  end
end
