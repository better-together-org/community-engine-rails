# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Included into Rails core ActiveStorage::Attachment (config/initializers/
    # content_security_attachment_hook.rb) so every attachment in the engine or a
    # host app is enrolled for malware scanning with no per-model code, the same
    # way Quotas::AttachmentTracking charges every attachment. Models that declare
    # scans_attachment keep their own enrollment path.
    #
    # Enrolling on attachment commit is the point where a direct or server-side
    # upload becomes a served file; a blob that is never attached is never served.
    module AttachmentHook
      extend ActiveSupport::Concern

      included do
        after_create_commit :enroll_in_content_security_scan
      end

      private

      def enroll_in_content_security_scan
        BetterTogether::ContentSecurity::AttachmentEnrollment.enroll_attachment!(attachment: self)
      rescue StandardError => e
        # No Item means the blob is not releasable, so a failure here fails closed
        # for serving. Report it and let the backfill task pick the attachment up.
        Rails.logger.warn("[ContentSecurity] enrollment failed for attachment #{id}: #{e.class}: #{e.message}")
        BetterTogether.report_error(e, context: { attachment_id: id, check: 'content_security_enrollment' })
      end
    end
  end
end
