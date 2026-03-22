# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list published pages
    # Respects privacy settings and publication status
    class ListPagesTool < ApplicationTool
      description 'List published pages with titles and content excerpts'
      tags :public

      arguments do
        optional(:privacy)
          .filled(:string)
          .description('Filter by privacy level: public or private')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
        optional(:topic_slug)
          .filled(:string)
          .description('Filter pages by topic category identifier (e.g. "employment", "housing")')
      end

      # List pages accessible to the current user
      # @param privacy [String] Optional privacy filter
      # @param limit [Integer] Maximum results (default: 20)
      # @param topic_slug [String] Optional topic category identifier filter
      # @return [String] JSON array of page objects
      def call(privacy: nil, limit: 20, topic_slug: nil)
        with_timezone_scope do
          pages = fetch_pages(privacy, limit, topic_slug: topic_slug)
          result = JSON.generate(pages.map { |page| serialize_page(page) })

          log_invocation('list_pages', { privacy: privacy, limit: limit, topic_slug: topic_slug }, result.bytesize)
          result
        end
      end

      private

      def topic_id_subquery(topic_slug)
        categories = Arel::Table.new(:better_together_categories)
        categories
          .project(categories[:id])
          .where(categories[:identifier].eq(topic_slug))
      end

      def categorizable_id_subquery(topic_slug, categorizable_type)
        categorizations = Arel::Table.new(:better_together_categorizations)
        categorizations
          .project(categorizations[:categorizable_id])
          .where(
            categorizations[:category_id].in(topic_id_subquery(topic_slug))
              .and(categorizations[:categorizable_type].eq(categorizable_type))
          )
      end

      def fetch_pages(privacy, limit, topic_slug: nil)
        scope = policy_scope(BetterTogether::Page)
        scope = scope.where(privacy: privacy) if privacy.present?
        if topic_slug.present?
          page_table = BetterTogether::Page.arel_table
          scope = scope.where(
            page_table[:id].in(
              categorizable_id_subquery(topic_slug, 'BetterTogether::Page')
            )
          )
        end
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
