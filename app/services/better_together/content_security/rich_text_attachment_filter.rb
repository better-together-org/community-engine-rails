# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Removes embedded attachments that are not yet cleared for public rendering.
    class RichTextAttachmentFilter
      RESTRICTED_VERDICTS = %w[blocked quarantined].freeze

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
        state = placeholder_state(attachment)

        <<~HTML
          <figure class="attachment attachment--file attachment--#{state} border rounded p-3 my-2 bg-light"
                  role="status"
                  aria-live="polite"
                  data-content-security-state="#{state}">
            <div class="fw-semibold">#{placeholder_title(state)}</div>
            <figcaption class="mb-0 text-muted">#{placeholder_message(attachment, state)}</figcaption>
          </figure>
        HTML
      end

      def placeholder_title(state)
        ERB::Util.html_escape(
          I18n.t(
            "better_together.content_security.attachments.#{state_key(state)}.title",
            default: state == 'content-restricted' ? 'Attachment restricted' : 'Attachment under review'
          )
        )
      end

      def placeholder_message(attachment, state)
        ERB::Util.html_escape(
          I18n.t(
            "better_together.content_security.attachments.#{state_key(state)}.message",
            default: placeholder_message_default(state),
            filename: attachment_filename(attachment)
          )
        )
      end

      def placeholder_message_default(state)
        return '%<filename>s is currently restricted while a reviewer checks it.' if state == 'content-restricted'

        '%<filename>s is being reviewed before it can be displayed.'
      end

      def attachment_filename(attachment)
        attachment.attachable.try(:filename).to_s.presence ||
          I18n.t('better_together.content_security.attachments.held.fallback_filename', default: 'This attachment')
      end

      def placeholder_state(attachment)
        subject = content_security_subject_for(attachment)
        return 'content-restricted' if subject&.aggregate_verdict.in?(RESTRICTED_VERDICTS)

        'held-review'
      end

      def content_security_subject_for(attachment)
        return unless attachment.attachable.is_a?(::ActiveStorage::Blob)

        Subject.for_blob(attachment.attachable).order(created_at: :desc).first
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def state_key(state)
        state == 'content-restricted' ? 'restricted' : 'held'
      end
    end
  end
end
