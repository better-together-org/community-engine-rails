# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Populates quota_usages retroactively so the ledger does not start from zero.
    # Safe to re-run: every write goes through BetterTogether::Quotas.settle!, whose
    # idempotency_key uniqueness guarantee is the only thing relied on for "run twice,
    # no duplicates" -- this class does no idempotency bookkeeping of its own.
    class Backfill
      Summary = Struct.new(
        :translation_usages, :attachment_usages, :reflection_attachment_count,
        :raw_attachment_count, :attachment_count_mismatch,
        keyword_init: true
      )

      def self.call
        new.call
      end

      def call
        translation_count = backfill_translations
        attachment_count, reflection_count, raw_count = backfill_attachments
        recalculate_touched_balances

        Summary.new(
          translation_usages: translation_count,
          attachment_usages: attachment_count,
          reflection_attachment_count: reflection_count,
          raw_attachment_count: raw_count,
          attachment_count_mismatch: reflection_count != raw_count
        )
      end

      private

      def backfill_translations
        count = 0
        BetterTogether::Ai::Log::Translation.where(status: 'success').find_each do |log|
          settle_translation(log)
          count += 1
        end
        count
      end

      def settle_translation(log)
        BetterTogether::Quotas.settle!(
          type: 'ai_translation_tokens',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(log),
          amount: log.tokens_used,
          idempotency_key: "ai_translation_tokens:backfill:#{log.id}",
          subject: log,
          actor: log.initiator,
          event: 'backfill'
        )
      end

      # Reflection-driven discovery, not a raw ActiveStorage::Attachment.find_each:
      # walks every loaded model (engine or host app) via reflect_on_all_attachments,
      # the same mechanism RemoveableAttachment uses, applied as discovery instead
      # of per-model opt-in. The raw-count cross-check proves it agrees with the
      # live global ActiveStorage::Attachment hook's own coverage.
      def backfill_attachments
        Rails.application.eager_load! unless Rails.env.production?

        count = 0
        attachment_bearing_classes.each do |klass|
          klass.find_each do |record|
            count += backfill_record_attachments(record)
          end
        end

        [count, count, ActiveStorage::Attachment.count]
      end

      def attachment_bearing_classes
        ActiveRecord::Base.descendants.select do |klass|
          klass.respond_to?(:reflect_on_all_attachments) && klass.reflect_on_all_attachments.any?
        rescue StandardError
          false
        end
      end

      def backfill_record_attachments(record)
        count = 0
        record.class.reflect_on_all_attachments.each do |reflection|
          attachments_for(record, reflection).each do |attachment|
            next unless attachment.persisted?

            settle_attachment(record, attachment)
            count += 1
          end
        end
        count
      end

      def attachments_for(record, reflection)
        proxy = record.public_send(reflection.name)
        if reflection.is_a?(ActiveStorage::Reflection::HasOneAttachedReflection)
          proxy.attachment ? [proxy.attachment] : []
        else
          proxy.attachments.to_a
        end
      end

      def settle_attachment(record, attachment)
        BetterTogether::Quotas.settle!(
          type: 'media_storage',
          owner: BetterTogether::Quotas::OwnerResolver.resolve(record),
          amount: attachment.blob.byte_size,
          idempotency_key: "media_storage:backfill:attachment:#{attachment.id}",
          subject: attachment,
          event: 'backfill'
        )
      end

      def recalculate_touched_balances
        BetterTogether::Quota.find_each do |quota|
          quota.quota_usages.distinct.pluck(:period_key).each do |period_key|
            BetterTogether::QuotaBalance.recalculate!(quota, period_key)
          end
        end
      end
    end
  end
end
