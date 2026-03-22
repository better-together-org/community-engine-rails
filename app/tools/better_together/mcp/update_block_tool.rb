# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to update content block attributes (sparse update).
    # Only the attrs provided in `attrs` are changed; all others remain untouched.
    # The block type cannot be changed after creation.
    class UpdateBlockTool < ApplicationTool
      description 'Update a content block\'s attributes (sparse — only provided attrs change)'
      tags :authenticated

      arguments do
        required(:block_id)
          .filled(:string)
          .description('Block UUID to update')
        required(:attrs)
          .filled(:hash)
          .description('Attributes to update, e.g. { heading_en: "New title", open_first: "false" }')
        optional(:identifier)
          .maybe(:string)
          .description('Update the block identifier (slug)')
        optional(:privacy)
          .filled(:string)
          .description('Update privacy: public or private')
      end

      # @return [String] JSON with updated block summary or error
      def call(block_id:, attrs:, identifier: nil, privacy: nil)
        return auth_required_response unless current_user

        with_timezone_scope do
          block = BetterTogether::Content::Block.find_by(id: block_id)
          return JSON.generate({ error: "Block not found: #{block_id}" }) unless block

          authorize block, :update?

          apply_updates(block, attrs, identifier, privacy)
        end
      rescue Pundit::NotAuthorizedError
        JSON.generate({ error: 'Not authorized to update this block' })
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def apply_updates(block, attrs, identifier, privacy) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        block.identifier = identifier if identifier.present?
        block.privacy = privacy if privacy.present?

        permitted = block.class.extra_permitted_attributes +
                    (block.class.respond_to?(:localized_attribute_list) ? block.class.localized_attribute_list : [])

        attrs.each do |key, value|
          attr_sym = key.to_sym
          next unless permitted.include?(attr_sym)

          block.public_send(:"#{attr_sym}=", value) if block.respond_to?(:"#{attr_sym}=")
        end

        if block.save
          result = JSON.generate({
                                   block_id: block.id,
                                   block_type: block.type,
                                   block_name: block.block_name,
                                   identifier: block.identifier,
                                   updated_at: block.updated_at.iso8601
                                 })
          log_invocation('update_block', { block_id: block.id, attrs: attrs.keys }, result.bytesize)
          result
        else
          JSON.generate({ error: 'Validation failed', details: block.errors.full_messages })
        end
      end
    end
  end
end
