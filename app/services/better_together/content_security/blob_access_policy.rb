# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Determines public proxy and download access for content-security-scanned blobs.
    class BlobAccessPolicy
      class << self
        def public_proxy_allowed?(blob)
          item = item_for(blob)
          return true unless scannable_blob?(blob)

          item&.releasable? == true
        end

        def download_allowed_for_record?(record, attachment_name)
          return true unless Configuration.enabled?

          config = record.class.try(:scannable_attachment_config_for, attachment_name)
          return true unless config
          return false unless Configuration.enabled_for_surface?(config.fetch(:surface))

          attachment = record.public_send(attachment_name)
          return true unless attachment.attached?

          item = Item.for_attachment(record, attachment_name).find_by(blob_id: attachment.blob_id)
          item&.releasable? == true
        end

        def scannable_blob?(blob)
          attachment_context_for(blob).present?
        end

        def attachment_context_for(blob)
          blob.attachments.each do |attachment|
            config = attachment.record.class.try(:scannable_attachment_config_for, attachment.name)
            next unless config
            next unless Configuration.enabled_for_surface?(config.fetch(:surface))

            return { attachment: attachment, config: config }
          end

          nil
        end

        def item_for(blob)
          context = attachment_context_for(blob)
          return nil unless context

          attachment = context.fetch(:attachment)
          Item.for_attachment(attachment.record, attachment.name).find_by(blob_id: blob.id)
        end
      end
    end
  end
end
