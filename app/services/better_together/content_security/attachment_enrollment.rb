# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Syncs an attachment into a content-security Item and enqueues scanning when the blob changes.
    class AttachmentEnrollment
      class << self
        def sync_attachment!(record:, attachment_name:, surface:)
          return unless Configuration.enabled_for_surface?(surface)

          attachment = record.public_send(attachment_name)
          return unless attachment.attached?

          item = Item.for_attachment(record, attachment_name).first_or_initialize
          blob_changed = item.new_record? || item.blob_id != attachment.blob_id
          assign_item_attributes!(item, record, attachment_name, attachment, surface)
          reset_pending_scan_fields!(item) if blob_changed
          schedule_scan_if_needed!(item, blob_changed)
        end

        private

        def assign_item_attributes!(item, record, attachment_name, attachment, surface)
          item.assign_attributes(
            blob: attachment.blob,
            attachable: record,
            attachment_name: attachment_name.to_s,
            source_surface: surface.to_s
          )
        end

        def reset_pending_scan_fields!(item)
          item.lifecycle_state = 'pending_scan'
          item.aggregate_verdict = 'pending_scan'
          item.scanned_at = nil
          item.released_at = nil
          item.last_error_class = nil
          item.last_error_summary = nil
        end

        def schedule_scan_if_needed!(item, blob_changed)
          item.save! if item.changed?
          return unless blob_changed || item.lifecycle_state_pending_scan?

          BetterTogether::ContentSecurity::ScanAttachmentJob.perform_later(item.id)
        end
      end
    end
  end
end
