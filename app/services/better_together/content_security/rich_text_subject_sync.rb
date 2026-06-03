# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Synchronizes content-security subjects for Active Storage blobs embedded in Action Text.
    class RichTextSubjectSync
      def initialize(rich_text:)
        @rich_text = rich_text
      end

      def call
        return purge! unless syncable?

        current_attachment_names = embedded_blobs.map { |blob| sync_subject_for(blob).attachment_name }

        if current_attachment_names.empty?
          subject_scope.delete_all
        else
          subject_scope.where.not(attachment_name: current_attachment_names).delete_all
        end
      end

      def purge!
        return unless rich_text.record.present? && rich_text.name.present?

        subject_scope.delete_all
      end

      private

      attr_reader :rich_text

      def syncable?
        rich_text.record.present? && rich_text.name.present?
      end

      def embedded_blobs
        @embedded_blobs ||= rich_text.body&.attachables.to_a.grep(::ActiveStorage::Blob).uniq
      end

      def sync_subject_for(blob)
        subject = Subject.find_or_initialize_by(subject: rich_text.record, attachment_name: attachment_name_for(blob))
        blob_changed = subject.new_record? || subject.active_storage_blob_id != blob.id

        subject.active_storage_blob = blob
        subject.source_surface = source_surface
        subject.storage_ref = "active_storage/blob/#{blob.id}"
        subject.reset_to_pending_review! if blob_changed
        subject.save! if subject.changed?
        subject
      end

      def attachment_name_for(blob)
        "#{rich_text.name}:embed:#{blob.id}"
      end

      def source_surface
        "ce_action_text:#{rich_text.record.class.model_name.singular}:#{rich_text.name}"
      end

      def subject_scope
        attachment_name = BetterTogether::ContentSecurity::Subject.arel_table[:attachment_name]

        BetterTogether::ContentSecurity::Subject.where(subject: rich_text.record)
                                                .where(attachment_name.matches("#{rich_text.name}:embed:%"))
      end
    end
  end
end
