# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Reserves media_storage bytes when ActiveStorage issues a signed direct-upload
    # URL -- generic across every direct-upload-origin attachment. Included
    # alongside, not into, DirectUploadAuthorization to keep that concern's
    # anti-abuse responsibility separate.
    #
    # The reservation's subject is the blob the request created, so the attachment
    # that later uses that blob settles it (AttachmentTracking); an upload that is
    # never attached stops counting once its TTL passes. Shadow mode only reserves,
    # so this runs after the blob exists; a later enforcement phase adds a
    # Quotas.check! before_action ahead of the upload instead.
    module DirectUploadReservation
      extend ActiveSupport::Concern

      included do
        after_action :reserve_media_storage_quota
      end

      private

      def reserve_media_storage_quota
        blob = direct_upload_blob
        return unless blob && blob.byte_size.to_i.positive?

        actor = direct_upload_person

        BetterTogether::Quotas.reserve!(
          type: 'media_storage',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(actor),
          amount: blob.byte_size,
          idempotency_key: "media_storage:reserve:blob:#{blob.id}",
          subject: blob,
          actor:,
          ttl: 10.minutes
        )
      rescue StandardError => e
        Rails.logger.warn("[Quotas] reserve! failed non-fatally for media_storage: #{e.class}: #{e.message}")
      end

      # Rails core DirectUploadsController#create keeps the blob in a local and only
      # renders it, so it is recovered from the signed_id in the JSON response.
      def direct_upload_blob
        return unless response.successful?

        signed_id = JSON.parse(response.body)['signed_id']
        signed_id && ActiveStorage::Blob.find_signed(signed_id)
      rescue JSON::ParserError
        nil
      end

      # Rails core controller: no current_person helper (that lives in
      # ApplicationHelper), so the signed-in user is read from warden directly, the
      # same way ApplicationConnection does. Pre-auth uploads (sign-up, host setup)
      # have no person and fall back to the Platform owner.
      def direct_upload_person
        request.env['warden']&.user(:user)&.person
      end
    end
  end
end
