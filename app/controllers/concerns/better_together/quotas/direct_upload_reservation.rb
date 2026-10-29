# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Reserves estimated media_storage bytes before ActiveStorage issues a signed
    # direct-upload URL -- generic across every direct-upload-origin attachment.
    # Included alongside, not into, DirectUploadAuthorization to keep that concern's
    # anti-abuse responsibility separate. No current_person here (Rails core
    # controller); pre-auth uploads fall back to the Platform owner.
    module DirectUploadReservation
      extend ActiveSupport::Concern

      included do
        before_action :reserve_media_storage_quota
      end

      private

      def reserve_media_storage_quota
        byte_size = params.dig(:blob, :byte_size).to_i
        return if byte_size <= 0

        actor = respond_to?(:current_person, true) ? current_person : nil

        BetterTogether::Quotas.reserve!(
          type: 'media_storage',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(actor),
          amount: byte_size,
          idempotency_key: "media_storage:reserve:#{request.request_id}",
          actor:,
          ttl: 10.minutes
        )
      rescue StandardError => e
        Rails.logger.warn("[Quotas] reserve! failed non-fatally for media_storage: #{e.class}: #{e.message}")
      end
    end
  end
end
