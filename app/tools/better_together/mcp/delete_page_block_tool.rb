# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to remove a content block from a page.
    #
    # By default only destroys the PageBlock join record (detaches the block from the page
    # but keeps the block available for reuse). Pass `destroy_block: true` to also delete
    # the block record — only allowed if the block is not attached to any other page.
    class DeletePageBlockTool < ApplicationTool
      description 'Remove a content block from a page (optionally destroy the block itself)'
      tags :authenticated

      arguments do
        required(:page_block_id)
          .filled(:string)
          .description('PageBlock join record UUID (from list_page_blocks)')
        optional(:destroy_block)
          .filled(:bool)
          .description('Also destroy the block record (default: false). Fails if block is on other pages.')
      end

      # @return [String] JSON with outcome
      def call(page_block_id:, destroy_block: false)
        return auth_required_response unless current_user

        with_timezone_scope do
          page_block = BetterTogether::Content::PageBlock.find_by(id: page_block_id)
          return JSON.generate({ error: "PageBlock not found: #{page_block_id}" }) unless page_block

          block = page_block.block
          authorize block, :destroy?

          detach_and_optionally_destroy(page_block, block, destroy_block)
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to delete this block' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def detach_and_optionally_destroy(page_block, block, destroy_block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        page_id = page_block.page_id
        block_id = block.id
        block_type = block.type

        page_block.destroy!

        if destroy_block
          other_pages = block.pages.count
          if other_pages.positive?
            return JSON.generate({
                                   error: "Block is attached to #{other_pages} other page(s). " \
                                          'Detached from this page only.',
                                   page_block_id: page_block.id,
                                   block_id: block_id
                                 })
          end

          block.destroy!
          block_destroyed = true
        end

        result = JSON.generate({
                                 page_block_id: page_block.id,
                                 block_id: block_id,
                                 block_type: block_type,
                                 page_id: page_id,
                                 block_destroyed: block_destroyed || false
                               })
        log_invocation('delete_page_block',
                       { page_block_id: page_block.id, destroy_block: destroy_block },
                       result.bytesize)
        result
      rescue ActiveRecord::RecordNotDestroyed => e
        JSON.generate({ error: 'Failed to delete', details: e.message })
      end
    end
  end
end
