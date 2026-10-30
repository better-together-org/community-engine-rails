# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TranslationBot do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  describe '#translate quota settlement' do
    let(:platform) { create(:platform) }
    let!(:robot) do
      create(:robot, :global, identifier: 'translation', provider: 'openai', default_model: nil,
                              system_prompt: 'Translate without adding commentary.')
    end

    before do
      allow(BetterTogether).to receive(:llm_chat).and_return(
        content: 'Bonjour',
        model: BetterTogether::Robot::DEFAULT_CHAT_MODEL,
        prompt_tokens: 5,
        completion_tokens: 2
      )
      allow(BetterTogether::Ai::Log::TranslationLoggerJob).to receive(:perform_later)
    end

    it 'settles exactly one ai_translation_tokens usage row when an initiator is present' do
      initiator = create(:better_together_person)
      bot = described_class.new(platform:)

      expect do
        bot.translate('Hello', target_locale: 'fr', source_locale: 'en', initiator:)
      end.to change(BetterTogether::QuotaUsage, :count).by(1)

      usage = BetterTogether::QuotaUsage.last
      expect(usage.quota_type).to eq('ai_translation_tokens')
      expect(usage.owner).to eq(initiator)
      expect(usage.amount).to eq(7)
      expect(usage.event).to eq('settle')
    end

    it 'still meters tokens when no initiator is given, charged to the host platform' do
      bot = described_class.new(platform:)

      expect do
        bot.translate('Hello', target_locale: 'fr', source_locale: 'en')
      end.to change(BetterTogether::QuotaUsage, :count).by(1)

      usage = BetterTogether::QuotaUsage.last
      expect(usage.owner).to eq(BetterTogether::Quotas::OwnerResolver.platform_fallback)
      expect(usage.actor).to be_nil
    end

    it 'settles each call separately even when the same initiator translates twice in one second' do
      initiator = create(:better_together_person)
      bot = described_class.new(platform:)

      freeze_time do
        expect do
          2.times { bot.translate('Hello', target_locale: 'fr', source_locale: 'en', initiator:) }
        end.to change(BetterTogether::QuotaUsage, :count).by(2)
      end
    end

    it 'keys the usage row by the log id handed to the logger job, the key the backfill reuses' do
      initiator = create(:better_together_person)
      bot = described_class.new(platform:)
      log_id = nil
      allow(BetterTogether::Ai::Log::TranslationLoggerJob).to receive(:perform_later) { |args| log_id = args[:log_id] }

      bot.translate('Hello', target_locale: 'fr', source_locale: 'en', initiator:)

      expect(log_id).to be_present
      expect(BetterTogether::QuotaUsage.last.idempotency_key).to eq(described_class.translation_charge_key(log_id))
    end

    it 'still enqueues Ai::Log::TranslationLoggerJob as before (no regression)' do
      initiator = create(:better_together_person)
      bot = described_class.new(platform:)

      bot.translate('Hello', target_locale: 'fr', source_locale: 'en', initiator:)

      expect(BetterTogether::Ai::Log::TranslationLoggerJob).to have_received(:perform_later)
        .with(hash_including(initiator:))
    end
  end
end
