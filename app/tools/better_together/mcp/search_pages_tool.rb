# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to search published pages by title or content
    # Respects privacy settings via Pundit policy scope
    class SearchPagesTool < ApplicationTool
      description 'Search published pages by title or content keywords, ' \
                  'respecting privacy settings'
      tags :public

      arguments do
        required(:query)
          .filled(:string)
          .description('Search query to match against page titles and content')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      def call(query:, limit: 20)
        with_timezone_scope do
          pages = search_accessible_pages(query, limit)
          result = JSON.generate(pages.map { |page| serialize_page(page) })
          log_invocation('search_pages', { query:, limit: }, result.bytesize)
          result
        end
      end

      private

      def search_accessible_pages(query, limit)
        policy_scope(BetterTogether::Page)
          .i18n
          .where(translatable_content_search_condition(BetterTogether::Page, query))
          .order(published_at: :desc)
          .limit([limit, 100].min)
      end

      def serialize_page(page)
        {
          id: page.id,
          title: page.title,
          slug: page.slug,
          excerpt: page.content&.to_plain_text&.truncate(200),
          privacy: page.privacy,
          published_at: page.published_at&.iso8601,
          url: BetterTogether::Engine.routes.url_helpers.page_path(page, locale: I18n.locale)
        }
      end
    end
  end
end
