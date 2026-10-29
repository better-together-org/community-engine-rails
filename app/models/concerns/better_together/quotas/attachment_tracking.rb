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

      # ActiveStorage::Attached::One/Many#detach calls Attachment#delete, not
      # #destroy, which bypasses ActiveRecord callbacks entirely (no
      # after_destroy_commit). Overriding delete directly is the only way to also
      # catch plain detach, the common path for replacing a profile/cover image.
      def delete
        reverse_media_storage_quota
        super
      end

      private

      def settle_media_storage_quota
        BetterTogether::Quotas.settle!(
          type: 'media_storage',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(record),
          amount: blob.byte_size,
          idempotency_key: "media_storage:settle:attachment:#{id}",
          subject: self
        )
      rescue StandardError => e
        Rails.logger.warn("[Quotas] settle! failed non-fatally for media_storage attachment #{id}: #{e.class}: #{e.message}")
      end

      # Reuses the settle row's own recorded owner and amount rather than
      # re-resolving `record`/`blob` fresh: (1) if the owner (e.g. a Post) was
      # destroyed in the same transaction, record may already be gone by the time
      # this fires post-commit, misattributing the reversal to the Platform
      # fallback; (2) Rails core's own after_destroy_commit :purge_dependent_blob_later
      # on ActiveStorage::Attachment can run before this callback and purge the
      # blob, making a fresh blob.byte_size read unreliable.
      def reverse_media_storage_quota
        original = BetterTogether::QuotaUsage.find_by(subject: self, event: 'settle')
        owner = original&.owner || BetterTogether::Quotas::OwnerResolver.resolve(record)
        amount = original&.amount || blob&.byte_size

        return unless amount

        BetterTogether::Quotas.reverse!(
          type: 'media_storage',
          owner:,
          amount:,
          idempotency_key: "media_storage:reverse:attachment:#{id}",
          subject: self
        )
      rescue StandardError => e
        Rails.logger.warn("[Quotas] reverse! failed non-fatally for media_storage attachment #{id}: #{e.class}: #{e.message}")
      end
    end
  end
end
