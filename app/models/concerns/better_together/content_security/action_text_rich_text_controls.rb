# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Adds CE content-security controls to Action Text rich text records.
    module ActionTextRichTextControls
      extend ActiveSupport::Concern

      included do
        validate :validate_supported_embeds_for_content_security

        after_commit :sync_embedded_attachment_content_security_subjects, on: %i[create update]
        after_destroy_commit :purge_embedded_attachment_content_security_subjects
      end

      private

      def sync_embedded_attachment_content_security_subjects
        BetterTogether::ContentSecurity::RichTextSubjectSync.new(rich_text: self).call
      end

      def purge_embedded_attachment_content_security_subjects
        BetterTogether::ContentSecurity::RichTextSubjectSync.new(rich_text: self).purge!
      end

      def validate_supported_embeds_for_content_security
        unsupported_attachables = body&.attachables.to_a.grep_v(::ActiveStorage::Blob)
        return if unsupported_attachables.blank?

        errors.add(:body, 'contains unsupported attachments; upload files into CE so they can be reviewed first')
      end
    end
  end
end
