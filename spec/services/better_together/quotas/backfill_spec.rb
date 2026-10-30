# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Backfill do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  describe '.call' do
    it 'backfills a translation usage row for an existing successful log, skipping failures' do
      initiator = create(:better_together_person)
      create(:ai_log_translation, initiator:, status: 'success', tokens_used: 42)
      create(:ai_log_translation, initiator:, status: 'failure', tokens_used: 999)

      summary = described_class.call

      expect(summary.translation_usages).to eq(1)
      usage = BetterTogether::QuotaUsage.find_by(event: 'backfill', quota_type: 'ai_translation_tokens')
      expect(usage.amount).to eq(42)
      expect(usage.owner).to eq(initiator)
    end

    it 'backfills a usage row for an existing attachment with no ledger row yet' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)
      upload.file.attach(io: StringIO.new('pre-existing'), filename: 'x.txt', content_type: 'text/plain')
      # The live hook already settled this; delete that row directly (bypassing the
      # model's own append-only guard via a raw SQL delete) to simulate the real
      # backfill scenario: an attachment that predates the ledger existing at all.
      BetterTogether::QuotaUsage.where(quota_type: 'media_storage').delete_all
      expect(BetterTogether::QuotaUsage.where(quota_type: 'media_storage')).not_to exist

      summary = described_class.call

      expect(summary.attachment_usages).to be >= 1
      usage = BetterTogether::QuotaUsage.find_by(
        event: 'backfill', quota_type: 'media_storage', subject: upload.file.attachment
      )
      expect(usage).to be_present
      expect(usage.owner).to eq(creator)
    end

    it 'is idempotent: running twice does not duplicate any row' do
      initiator = create(:better_together_person)
      create(:ai_log_translation, initiator:, status: 'success', tokens_used: 10)

      described_class.call
      count_after_first = BetterTogether::QuotaUsage.count
      described_class.call
      count_after_second = BetterTogether::QuotaUsage.count

      expect(count_after_second).to eq(count_after_first)
    end

    it 'does not charge an attachment the live hook already settled a second time' do
      upload = create(:better_together_upload)
      upload.file.attach(io: StringIO.new('live'), filename: 'x.txt', content_type: 'text/plain')
      attachment = upload.file.attachment

      described_class.call

      expect(BetterTogether::QuotaUsage.where(subject: attachment).count).to eq(1)
      expect(BetterTogether::QuotaUsage.find_by(subject: attachment).event).to eq('settle')
    end

    it 'does not charge a translation the live bot already settled a second time' do
      initiator = create(:better_together_person)
      log = create(:ai_log_translation, initiator:, tokens_used: 7)
      BetterTogether::Quotas.settle!(
        type: 'ai_translation_tokens', owner: initiator, amount: 7, actor: initiator,
        idempotency_key: BetterTogether::TranslationBot.translation_charge_key(log.id)
      )

      expect { described_class.call }
        .not_to change(BetterTogether::QuotaUsage.where(quota_type: 'ai_translation_tokens'), :count)
    end

    it 'files historical translation usage under the month it happened in' do
      log = travel_to(Time.zone.local(2025, 3, 14, 12)) { create(:ai_log_translation, tokens_used: 42) }

      described_class.call

      usage = BetterTogether::QuotaUsage.find_by(subject: log)
      expect(usage.period_key).to eq('2025-03')
    end

    it 'walks an STI hierarchy once, so subclass attachments are not counted twice' do
      # Content::Image < Content::Block: Block declares background_image_file and
      # Image adds media, so walking both classes would visit this media twice.
      create(:better_together_content_image)

      summary = described_class.call

      expect(summary.reflection_attachment_count).to eq(summary.raw_attachment_count)
    end

    it 'cross-checks the reflection-driven attachment count against the raw table count' do
      upload = create(:better_together_upload)
      upload.file.attach(io: StringIO.new('x'), filename: 'x.txt', content_type: 'text/plain')

      summary = described_class.call

      expect(summary.raw_attachment_count).to eq(ActiveStorage::Attachment.count)
      expect(summary.attachment_count_mismatch).to be false
    end
  end
end
