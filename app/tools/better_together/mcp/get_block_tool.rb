# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to retrieve a single content block with full attribute detail
    # Returns all content_data attrs, translatable attrs for all supported locales,
    # and the pages the block is attached to.
    class GetBlockTool < ApplicationTool
      description 'Get a content block by ID with full attributes and attached pages'
      tags :public

      SUPPORTED_LOCALES = %w[en fr es uk].freeze

      arguments do
        required(:block_id)
          .filled(:string)
          .description('Block UUID')
      end

      # @param block_id [String] Block UUID
      # @return [String] JSON object with full block detail
      def call(block_id:)
        with_timezone_scope do
          block = BetterTogether::Content::Block.find_by(id: block_id)
          return JSON.generate({ error: "Block not found: #{block_id}" }) unless block

          authorize block, :show?

          result = JSON.generate(serialize_block(block))
          log_invocation('get_block', { block_id: }, result.bytesize)
          result
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to view this block' })
      end

      private

      def serialize_block(block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        {
          id: block.id,
          type: block.type,
          block_name: block.block_name,
          identifier: block.identifier,
          privacy: block.privacy,
          visible: block.visible,
          protected: block.protected,
          created_at: block.created_at.iso8601,
          updated_at: block.updated_at.iso8601,
          pages: block.pages.map { |p| { id: p.id, slug: p.slug_en, title: p.title_en } },
          translatable_attrs: translatable_attrs(block),
          content_data: block.respond_to?(:content_data) ? block.content_data : {}
        }
      end

      def translatable_attrs(block)
        return {} unless block.class.respond_to?(:localized_attribute_list)

        block.class.localized_attribute_list.filter_map do |locale_attr|
          # e.g. :markdown_source_en
          base, locale = locale_attr.to_s.match(/^(.+)_(#{SUPPORTED_LOCALES.join('|')})$/)&.captures
          next unless base && SUPPORTED_LOCALES.include?(locale)

          [locale_attr, block.respond_to?(locale_attr) ? block.send(locale_attr) : nil]
        end.to_h
      end
    end
  end
end
