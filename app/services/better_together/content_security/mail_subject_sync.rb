# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Surfaces held/errored inbound mail in the existing Subject review queue (Safety tab).
    #
    # Mirrors AttachmentSubjectSync/RichTextSubjectSync, but there is no ActiveStorage blob to
    # sync against — a Subject is only created once a message fails to pass screening. Passed
    # mail already completed its lifecycle (routed, or intentionally no-op) and needs no review.
    class MailSubjectSync
      ATTACHMENT_NAME = 'inbound_email'
      SOURCE_SURFACE = 'ce_inbound_mail'

      def initialize(message:)
        @message = message
      end

      def call
        return unless message.screening_state_held? || message.screening_state_error?

        subject = find_or_initialize_subject
        subject.source_surface = SOURCE_SURFACE
        subject.storage_ref = "inbound_email_message/#{message.id}"
        subject.reset_to_pending_review! if subject.new_record?
        subject.save! if subject.changed?
        subject
      end

      private

      attr_reader :message

      def find_or_initialize_subject
        Subject.find_or_initialize_by(subject: message, attachment_name: ATTACHMENT_NAME)
      end
    end
  end
end
