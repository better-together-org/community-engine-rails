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
          attachment_renderable?(attachment) ? attachment.node : held_attachment_placeholder(attachment)
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

      def held_attachment_placeholder(attachment)
        Nokogiri::HTML::DocumentFragment.parse(placeholder_html(attachment)).children.first
      end

      def placeholder_html(attachment)
        <<~HTML
          <figure class="attachment attachment--file attachment--held-review border rounded p-3 my-2 bg-light"
                  role="status"
                  aria-live="polite"
                  data-content-security-state="held-review">
            <div class="fw-semibold">#{placeholder_title}</div>
            <figcaption class="mb-0 text-muted">#{placeholder_message(attachment)}</figcaption>
          </figure>
        HTML
      end

      def placeholder_title
        ERB::Util.html_escape(
          I18n.t(
            'better_together.content_security.attachments.held.title',
            default: 'Attachment under review'
          )
        )
      end

      def placeholder_message(attachment)
        ERB::Util.html_escape(
          I18n.t(
            'better_together.content_security.attachments.held.message',
            default: '%<filename>s is being reviewed before it can be displayed.',
            filename: attachment_filename(attachment)
          )
        )
      end

      def attachment_filename(attachment)
        attachment.attachable.try(:filename).to_s.presence ||
          I18n.t('better_together.content_security.attachments.held.fallback_filename', default: 'This attachment')
      end
    end
  end
end
