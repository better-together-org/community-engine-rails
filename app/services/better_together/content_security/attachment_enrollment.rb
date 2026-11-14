# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Syncs an attachment into a content-security Item and enqueues scanning when the blob changes.
    class AttachmentEnrollment
      # Surface for attachments on models that do not declare scans_attachment.
      CATCH_ALL_SURFACE = 'attachments'

      class << self
        # Enrolls any ActiveStorage::Attachment, including has_many_attached slots
        # (one Item per blob). Declared scannable attachments use sync_attachment!.
        def enroll_attachment!(attachment:)
          return unless Configuration.enabled? && Configuration.enabled_for_surface?(CATCH_ALL_SURFACE)
          return unless catch_all_attachment?(attachment)

          record = attachment.record
          item = Item.where(attachable: record, attachment_name: attachment.name.to_s,
                            blob_id: attachment.blob_id).first_or_initialize
          is_new = item.new_record?
          assign_item_attributes!(item, record, attachment.name, attachment, CATCH_ALL_SURFACE)
          reset_pending_scan_fields!(item) if is_new
          schedule_scan_if_needed!(item, is_new)
        end

        # True for attachments the catch-all surface is responsible for: a real
        # owner record (not a variant) that does not declare scans_attachment.
        def catch_all_attachment?(attachment)
          record = attachment.record
          return false if record.nil? || record.is_a?(::ActiveStorage::VariantRecord)

          record.class.try(:scannable_attachment_config_for, attachment.name).blank?
        end

        def sync_attachment!(record:, attachment_name:, surface:)
          return unless Configuration.enabled?
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
          return unless blob_changed

          BetterTogether::ContentSecurity::ScanAttachmentJob.perform_later(item.id)
        rescue ActiveRecord::RecordNotUnique
          reloaded = Item.for_attachment(item.attachable, item.attachment_name)
                         .find_by(blob_id: item.blob_id)
          BetterTogether::ContentSecurity::ScanAttachmentJob.perform_later(reloaded.id) if reloaded
        end
      end
    end
  end
end
