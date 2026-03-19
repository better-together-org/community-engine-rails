# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list content blocks on a page
    # Returns block type, ID, identifier, and key content attrs in positional order.
    class ListPageBlocksTool < ApplicationTool
      description 'List content blocks attached to a page, in display order'
      tags :authenticated

      arguments do
        required(:page_id)
          .filled(:string)
          .description('Page UUID or slug to list blocks for')
      end

      # @param page_id [String] Page UUID or slug
      # @return [String] JSON array of block objects
      def call(page_id:)
        with_timezone_scope do
          page = find_page(page_id)
          return JSON.generate({ error: "Page not found: #{page_id}" }) unless page

          authorize page, :show?

          blocks = page.page_blocks
                       .includes(:block)
                       .order(:position)
                       .map { |pb| serialize_page_block(pb) }

          result = JSON.generate({ page_id: page.id, page_slug: page.slug_en, blocks: })
          log_invocation('list_page_blocks', { page_id: }, result.bytesize)
          result
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to view this page' })
      end

      private

      def find_page(page_id)
        scope = policy_scope(BetterTogether::Page)
        page = scope.find_by(id: page_id)
        page ||= scope.joins(:string_translations)
                      .where(
                        mobility_string_translations: {
                          translatable_type: 'BetterTogether::Page',
                          key: 'slug',
                          value: page_id
                        }
                      ).first
        page
      end

      def serialize_page_block(page_block)
        block = page_block.block
        {
          page_block_id: page_block.id,
          position: page_block.position,
          block_id: block.id,
          block_type: block.type,
          block_name: block.block_name,
          identifier: block.identifier,
          privacy: block.privacy,
          summary: block_summary(block)
        }
      end

      # Returns a brief human-readable summary of the block's content
      # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      def block_summary(block)
        case block
        when BetterTogether::Content::Markdown
          block.respond_to?(:markdown_source_en) ? block.markdown_source_en.to_s.truncate(120) : ''
        when BetterTogether::Content::Hero
          block.respond_to?(:heading_en) ? block.heading_en.to_s.truncate(80) : ''
        when BetterTogether::Content::AccordionBlock
          "#{block.parsed_accordion_items.size} item(s) — #{block.heading.presence || '(no heading)'}"
        when BetterTogether::Content::AlertBlock
          "[#{block.alert_level}] #{block.body_text.to_s.truncate(80)}"
        when BetterTogether::Content::CallToActionBlock
          block.heading.presence || block.primary_button_label.presence || '(empty CTA)'
        when BetterTogether::Content::QuoteBlock
          block.quote_text.to_s.truncate(100)
        when BetterTogether::Content::StatisticsBlock
          "#{block.parsed_stats.size} stat(s) — #{block.heading.presence || '(no heading)'}"
        when BetterTogether::Content::VideoBlock
          block.video_url.to_s.truncate(80)
        when BetterTogether::Content::CommunitiesBlock,
             BetterTogether::Content::PeopleBlock,
             BetterTogether::Content::EventsBlock,
             BetterTogether::Content::PostsBlock
          "#{block.block_name} — limit #{block.item_limit}"
        when BetterTogether::Content::NavigationAreaBlock
          "nav_area_id=#{block.navigation_area_id}"
        when BetterTogether::Content::MermaidDiagram
          block.respond_to?(:diagram_source_en) ? block.diagram_source_en.to_s.truncate(80) : ''
        when BetterTogether::Content::Css
          len = block.respond_to?(:content_en) ? block.content_en.to_s.length : 0
          "#{len} chars of CSS"
        else
          block.identifier.presence || block.block_name
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
    end
  end
end
