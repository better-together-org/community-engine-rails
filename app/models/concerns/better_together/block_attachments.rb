# frozen_string_literal: true

module BetterTogether
  # Attaches existing blocks (created through the blocks API) at the top of a record's rich text body, in the order of
  # `attachment_block_ids`. Only classes in ContentSecurity::AttachableRegistry that belong to the record's platform
  # are accepted. A body update keeps the blocks the record already shows: new text sent without any attachment has
  # the existing attachments put back in front of it, and `attachment_block_ids` sent on update replace them.
  module BlockAttachments
    extend ActiveSupport::Concern

    included do
      attr_accessor :attachment_block_ids

      validate :attachment_blocks_must_be_attachable, if: :attaching_blocks?
      before_save :attach_blocks, if: :attaching_blocks?
      before_update :keep_attachments, unless: :attaching_blocks?
      after_save { self.attachment_block_ids = nil }
    end

    private

    def attachment_ids_to_attach
      Array(attachment_block_ids).compact_blank
    end

    def attaching_blocks?
      attachment_ids_to_attach.any?
    end

    def attachable_block(id)
      block = BetterTogether::Content::Block.find_by(id:, platform_id:)
      block if block && ContentSecurity::AttachableRegistry.allowed?(block)
    end

    def attachment_blocks_must_be_attachable
      return unless attachment_ids_to_attach.any? { |id| attachable_block(id).nil? }

      errors.add(:attachment_block_ids, :invalid)
    end

    def attachments_html(blocks)
      blocks.map { |block| ActionText::Attachment.from_attachable(block).to_html }.join
    end

    def block_attachables(record)
      record.content.body.attachables.grep(BetterTogether::Content::Block)
    end

    def attach_blocks
      html = attachments_html(attachment_ids_to_attach.filter_map { |id| attachable_block(id) })
      self.content = html + content.body.to_html.to_s if html.present?
    end

    # New text sent without attachments must not drop the blocks the record already shows.
    def keep_attachments
      return unless persisted? && block_attachables(self).empty?

      html = attachments_html(block_attachables(self.class.find(id)))
      self.content = html + content.body.to_html.to_s if html.present?
    end
  end
end
