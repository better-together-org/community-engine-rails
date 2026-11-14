# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Included into Rails core ActiveStorage::Attachment (config/initializers/
    # quotas.rb) so every attachment in the engine or a host app settles/reverses
    # with no per-model code -- ActiveStorage::Attachment is one shared Rails-core
    # class regardless of which model declares the association.
    module AttachmentTracking
      extend ActiveSupport::Concern

      included do
        after_create_commit :settle_media_storage_quota
        after_destroy_commit :reverse_media_storage_quota
      end

      # The one idempotency key for an attachment's charge, shared by the live
      # settle below and Quotas::Backfill, so an attachment is charged at most once
      # whichever path writes first.
      def self.charge_key(attachment_id)
        "media_storage:settle:attachment:#{attachment_id}"
      end

      # ActiveStorage::Attached::One#detach and Attachment#purge call
      # Attachment#delete, not #destroy, which bypasses ActiveRecord callbacks
      # entirely (no after_destroy_commit). Overriding delete directly catches those.
      # has_many_attached detach goes through a relation delete_all instead; see
      # DetachManyTracking.
      def delete
        reverse_media_storage_quota
        super
      end

      # Reverses exactly the charge recorded for this attachment, reusing that row's
      # owner and amount rather than re-resolving `record`/`blob`: (1) if the owner
      # (e.g. a Post) was destroyed in the same transaction, record may already be
      # gone by the time this fires post-commit; (2) Rails core's own
      # after_destroy_commit :purge_dependent_blob_later can purge the blob first.
      # No charge row (an attachment from before deploy that the backfill hasn't
      # covered yet, or an owner whose ledger was erased) means nothing to reverse.
      def reverse_media_storage_quota
        charge = BetterTogether::QuotaUsage.find_by(idempotency_key: AttachmentTracking.charge_key(id))
        return unless charge

        BetterTogether::Quotas.reverse!(
          type: 'media_storage',
          owner: charge.owner,
          amount: charge.amount,
          idempotency_key: "media_storage:reverse:attachment:#{id}",
          subject: self
        )
      rescue StandardError => e
        Rails.logger.warn("[Quotas] reverse! failed non-fatally for media_storage attachment #{id}: #{e.class}: #{e.message}")
      end

      private

      def settle_media_storage_quota
        BetterTogether::Quotas.settle!(
          type: 'media_storage',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(record),
          amount: blob.byte_size,
          idempotency_key: AttachmentTracking.charge_key(id),
          subject: self
        )
        BetterTogether::Quotas.settle_reservations_for!(blob)
      rescue StandardError => e
        Rails.logger.warn("[Quotas] settle! failed non-fatally for media_storage attachment #{id}: #{e.class}: #{e.message}")
      end
    end
  end
end
