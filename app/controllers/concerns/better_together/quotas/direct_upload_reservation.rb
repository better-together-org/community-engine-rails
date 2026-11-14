# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Holds media_storage bytes for a direct upload BEFORE ActiveStorage issues the signed URL, so a platform in
    # `hard` mode can refuse an upload that would pass the limit, and two uploads racing for the last bytes cannot
    # both be allowed (the check and the hold happen under the quota's lock, see Quotas.reserve!). Generic across
    # every direct-upload-origin attachment. Included alongside, not into, DirectUploadAuthorization to keep that
    # concern's anti-abuse responsibility separate.
    #
    # The hold is made from the size the client declares, then tied to the blob the request created, so the
    # attachment that later uses that blob settles it (AttachmentTracking). A request that creates no blob releases
    # its hold, and an upload that is never attached stops counting once its TTL passes (ExpireQuotaReservationsJob).
    # A failure in the quota code itself never stops an upload: it is recorded and the upload goes ahead.
    module DirectUploadReservation
      extend ActiveSupport::Concern

      # A declared size above this is refused outright: one request cannot hold a whole quota
      # (or, for a pre-auth upload, the platform's) by claiming an absurd size.
      MAX_DECLARED_BYTES = 5 * (1024**3)

      included do
        before_action :hold_media_storage_quota
        after_action :link_media_storage_hold
      end

      private

      def hold_media_storage_quota
        bytes = declared_upload_bytes
        return unless bytes.positive?
        return render_storage_limit_reached if bytes > MAX_DECLARED_BYTES

        actor = direct_upload_person
        @media_storage_hold = BetterTogether::Quotas.reserve!(
          type: 'media_storage', owner: BetterTogether::Quotas::OwnerResolver.resolve(actor, type: 'media_storage'), amount: bytes,
          idempotency_key: "media_storage:hold:#{SecureRandom.uuid}", actor:, ttl: 10.minutes
        )
      rescue BetterTogether::Quotas::QuotaExceeded
        render_storage_limit_reached
      rescue StandardError => e
        BetterTogether::Quotas.record_failure(e, 'media_storage direct upload hold')
      end

      def render_storage_limit_reached
        render json: { error: I18n.t('better_together.quotas.storage_limit_reached') }, status: :unprocessable_content
      end

      def link_media_storage_hold
        return unless @media_storage_hold

        blob = direct_upload_blob
        if blob
          @media_storage_hold.update!(subject: blob)
        else
          release_media_storage_hold
        end
      rescue StandardError => e
        BetterTogether::Quotas.record_failure(e, 'media_storage direct upload link')
      end

      def release_media_storage_hold
        @media_storage_hold.update!(status: 'released')
        BetterTogether::QuotaBalance.refresh_reserved!(@media_storage_hold.quota, @media_storage_hold.period_key)
      end

      def declared_upload_bytes
        params.dig(:blob, :byte_size).to_i
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
