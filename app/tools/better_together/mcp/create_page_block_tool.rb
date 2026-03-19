# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to create a new content block and attach it to a page.
    #
    # Block type determines which attrs are relevant. All content_data and
    # translatable attrs can be passed as flat kwargs; unrecognised keys are ignored.
    #
    # The block is appended to the page at the next available position unless
    # `position` is specified.
    class CreatePageBlockTool < ApplicationTool
      description 'Create a content block and attach it to a page at the given position'
      tags :authenticated

      # Minimum args shared by all block types.
      # Block-specific attrs (heading, body_text, video_url, etc.) are passed via `attrs`.
      arguments do
        required(:page_id)
          .filled(:string)
          .description('Page UUID or slug to attach the block to')
        required(:block_type)
          .filled(:string)
          .description('Full block class name, e.g. BetterTogether::Content::AccordionBlock')
        optional(:identifier)
          .maybe(:string)
          .description('Optional slug identifier for the block (auto-generated if blank)')
        optional(:privacy)
          .filled(:string)
          .description('public or private (default: public)')
        optional(:position)
          .filled(:integer)
          .description('Position on the page (appends if omitted)')
        optional(:attrs)
          .filled(:hash)
          .description('Block-specific attributes as a hash, e.g. { heading: "FAQ", open_first: "true" }')
      end

      # @return [String] JSON with created block + page_block details
      def call(page_id:, block_type:, identifier: nil, privacy: 'public', position: nil, attrs: {}) # rubocop:disable Metrics/ParameterLists
        return auth_required_response unless current_user

        with_timezone_scope do
          page = find_page(page_id)
          return JSON.generate({ error: "Page not found: #{page_id}" }) unless page

          authorize page, :update?

          block_class = resolve_block_class(block_type)
          return JSON.generate({ error: "Unknown block type: #{block_type}" }) unless block_class

          block = build_block(block_class, identifier, privacy, attrs)
          authorize block, :create?

          save_block_and_attach(block, page, position)
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def find_page(page_id)
        BetterTogether::Page.find_by(id: page_id) ||
          BetterTogether::Page.joins(:string_translations)
                              .where(
                                mobility_string_translations: {
                                  translatable_type: 'BetterTogether::Page',
                                  key: 'slug',
                                  value: page_id
                                }
                              ).first
      end

      def resolve_block_class(block_type)
        # Normalize to the BetterTogether::Content namespace to prevent arbitrary
        # constant loading from user-supplied input.
        name = block_type.to_s
                         .delete_prefix('BetterTogether::Content::')
                         .delete_prefix('Content::')
        klass = "BetterTogether::Content::#{name}".safe_constantize
        return nil unless klass && klass < ::BetterTogether::Content::Block

        klass
      end

      def build_block(block_class, identifier, privacy, attrs)
        block = block_class.new(privacy: privacy)
        block.identifier = identifier if identifier.present?

        # Apply permitted content_data and translatable attrs
        permitted = block_class.extra_permitted_attributes +
                    (block_class.respond_to?(:localized_attribute_list) ? block_class.localized_attribute_list : [])

        attrs.each do |key, value|
          attr_sym = key.to_sym
          next unless permitted.include?(attr_sym)

          block.public_send(:"#{attr_sym}=", value) if block.respond_to?(:"#{attr_sym}=")
        end

        block
      end

      def save_block_and_attach(block, page, position) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        ActiveRecord::Base.transaction do
          unless block.save
            return JSON.generate({ error: 'Block validation failed', details: block.errors.full_messages })
          end

          max = page.page_blocks.maximum(:position)
          pos = position || (max ? max + 1 : 0)
          page_block = BetterTogether::Content::PageBlock.create!(
            page: page,
            block: block,
            position: pos
          )

          result = JSON.generate({
                                   block_id: block.id,
                                   block_type: block.type,
                                   block_name: block.block_name,
                                   page_block_id: page_block.id,
                                   position: page_block.position,
                                   page_id: page.id,
                                   page_slug: page.slug_en
                                 })
          log_invocation('create_page_block',
                         { page_id: page.id, block_type: block.type, position: pos },
                         result.bytesize)
          result
        end
      rescue ActiveRecord::RecordInvalid => e
        JSON.generate({ error: 'Failed to attach block to page', details: e.message })
      end
    end
  end
end
