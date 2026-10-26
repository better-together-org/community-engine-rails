# frozen_string_literal: true

module BetterTogether
  # Attaches existing blocks (created through the blocks API) to a record's rich text body, in the order of
  # `attachment_block_ids`. Only classes in ContentSecurity::AttachableRegistry that belong to the record's platform
  # are accepted.
  #
  # By default the blocks go at the top of `content` (a post). A model whose body is another field, or that wants
  # the picture under the text, says so with `attaches_blocks_to :description, at: :end`.
  #
  # At the top: a body update keeps the blocks the record already shows (new text sent without any attachment has
  # the existing attachments put back in front of it) and `attachment_block_ids` sent on update replace them.
  # At the end: a block already in the body is not added twice, so sending the same ids again changes nothing, and
  # the caller owns the rest of the body.
  module BlockAttachments
    extend ActiveSupport::Concern

    included do
      class_attribute :block_attachments_field, default: :content, instance_writer: false
      class_attribute :block_attachments_position, default: :start, instance_writer: false

      attr_accessor :attachment_block_ids

      validate :attachment_blocks_must_be_attachable, if: :attaching_blocks?
      before_save :attach_blocks, if: :attaching_blocks?
      before_update :keep_attachments, unless: :attaching_blocks?
      after_save { self.attachment_block_ids = nil }
    end

    class_methods do
      def attaches_blocks_to(field, at: :start)
        self.block_attachments_field = field
        self.block_attachments_position = at
      end
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
      (record.public_send(block_attachments_field).body&.attachables || []).grep(BetterTogether::Content::Block)
    end

    def block_body_html
      public_send(block_attachments_field).body&.to_html.to_s
    end

    def attach_blocks
      blocks = attachment_ids_to_attach.filter_map { |id| attachable_block(id) }
      blocks -= block_attachables(self) if block_attachments_position == :end
      html = attachments_html(blocks)
      return if html.blank?

      write_block_body(block_attachments_position == :end ? block_body_html + html : html + block_body_html)
    end

    # New text sent without attachments must not drop the blocks the record already shows.
    def keep_attachments
      return unless block_attachments_position == :start && persisted? && block_attachables(self).empty?

      html = attachments_html(block_attachables(self.class.find(id)))
      write_block_body(html + block_body_html) if html.present?
    end

    def write_block_body(html)
      public_send(:"#{block_attachments_field}=", html)
    end
  end
end
