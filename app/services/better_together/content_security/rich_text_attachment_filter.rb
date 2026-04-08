# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Removes embedded attachments that are not yet cleared for public rendering.
    class RichTextAttachmentFilter
      def initialize(content)
        @content = content
      end

      def call
        return content if content.blank?

        content.render_attachments do |attachment|
          attachment_renderable?(attachment) ? attachment.node : ''
        end
      end

      private

      attr_reader :content

      def attachment_renderable?(attachment)
        attachment.attachable.is_a?(::ActiveStorage::Blob) &&
          BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(attachment.attachable)
      rescue ActiveRecord::RecordNotFound
        false
      end
    end
  end
end
