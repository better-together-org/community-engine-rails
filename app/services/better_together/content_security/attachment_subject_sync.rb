# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Ensures attachment-backed subjects start in a held state until released.
    class AttachmentSubjectSync
      def initialize(record:, attachment_name:, source_surface:)
        @record = record
        @attachment_name = attachment_name.to_s
        @source_surface = source_surface
      end

      def call
        return destroy_subject! unless attachment.attached?

        subject = find_or_initialize_subject
        blob_changed = blob_changed?(subject)

        assign_attachment_attributes(subject)
        subject.reset_to_pending_review! if blob_changed
        subject.save! if subject.changed?
        subject
      end

      private

      attr_reader :attachment_name, :record, :source_surface

      def attachment
        @attachment ||= record.public_send(attachment_name)
      end

      def assign_attachment_attributes(subject)
        subject.active_storage_blob = attachment.blob
        subject.source_surface = source_surface
        subject.storage_ref = "active_storage/blob/#{attachment.blob.id}"
      end

      def blob_changed?(subject)
        subject.new_record? || subject.active_storage_blob_id != attachment.blob.id
      end

      def destroy_subject!
        Subject.find_by(subject: record, attachment_name: attachment_name)&.destroy!
      end

      def find_or_initialize_subject
        Subject.find_or_initialize_by(subject: record, attachment_name: attachment_name)
      end
    end
  end
end
