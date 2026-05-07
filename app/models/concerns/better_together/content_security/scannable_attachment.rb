# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Concern that enrolls ActiveRecord attachments in content-security scanning on commit.
    module ScannableAttachment
      extend ActiveSupport::Concern

      included do
        class_attribute :scannable_attachments, default: {}
        after_commit :sync_content_security_attachments
      end

      class_methods do
        def scans_attachment(name, surface:)
          self.scannable_attachments = scannable_attachments.merge(
            name.to_s => { surface: surface.to_s }
          )
        end

        def scannable_attachment_config_for(name)
          scannable_attachments[name.to_s]
        end
      end

      private

      def sync_content_security_attachments
        return unless BetterTogether::ContentSecurity::Configuration.enabled?

        self.class.scannable_attachments.each do |attachment_name, config|
          BetterTogether::ContentSecurity::AttachmentEnrollment.sync_attachment!(
            record: self,
            attachment_name: attachment_name,
            surface: config.fetch(:surface)
          )
        end
      end
    end
  end
end
