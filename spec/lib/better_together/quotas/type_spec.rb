# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Type do
  describe '.find' do
    it 'resolves media_storage to its registered class' do
      expect(described_class.find('media_storage')).to eq(BetterTogether::Quotas::Types::MediaStorage)
    end

    it 'resolves ai_translation_tokens to its registered class' do
      expect(described_class.find('ai_translation_tokens'))
        .to eq(BetterTogether::Quotas::Types::AiTranslationTokens)
    end

    it 'raises for an unknown key' do
      expect { described_class.find('not_a_real_type') }.to raise_error(KeyError)
    end
  end

  describe '.keys' do
    it 'includes both known types' do
      expect(described_class.keys).to include('media_storage', 'ai_translation_tokens')
    end
  end

  describe '.available' do
    let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
    let(:openai_key) { nil }

    before do
      BetterTogether::Robot.update_all(active: false) # rubocop:disable Rails/SkipsModelValidations
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(openai_key)
      allow(ENV).to receive(:fetch).with('OPENAI_ACCESS_TOKEN', nil).and_return(nil)
      allow(ENV).to receive(:fetch).with('BETTER_TOGETHER_LLM_PROVIDER', anything).and_return('openai')
    end

    it 'always offers media_storage' do
      expect(described_class.available_keys(platform)).to include('media_storage')
    end

    it 'hides LLM usage tokens with no credentials and no translation robot' do
      expect(described_class.available_keys(platform)).not_to include('ai_translation_tokens')
    end

    context 'with only OPENAI_API_KEY set and default translation robot resolution' do
      let(:openai_key) { 'sk-test' }

      it 'offers LLM usage tokens' do
        expect(described_class.available_keys(platform)).to include('ai_translation_tokens')
      end
    end

    it 'offers LLM usage tokens when the translation robot uses ollama' do
      create(:better_together_robot, :global, :ollama, identifier: 'translation')

      expect(described_class.available_keys(platform)).to include('ai_translation_tokens')
    end

    it 'hides LLM usage tokens when the translation robot uses openai without credentials' do
      create(:better_together_robot, :global, identifier: 'translation')

      expect(described_class.available_keys(platform)).not_to include('ai_translation_tokens')
    end

    it 'hides LLM usage tokens when only a non-translation robot is active' do
      create(:better_together_robot, :global, :ollama, identifier: 'summary')

      expect(described_class.available_keys(platform)).not_to include('ai_translation_tokens')
    end

    it 'hides LLM usage tokens when RubyLLM has a key the translation gate does not see' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return('sk-rubyllm-only')

      expect(described_class.available_keys(platform)).not_to include('ai_translation_tokens')
    end
  end

  describe '.visible_for?' do
    let(:person) { create(:better_together_person) }

    it 'shows every row by default on the base class' do
      expect(described_class.visible_for?(instance_double(BetterTogether::Quota))).to be true
    end

    it 'shows a media_storage row with a zero limit' do
      quota = BetterTogether::Quota.create!(owner: person, quota_type: 'media_storage', limit: 0, period: 'cumulative')

      expect(BetterTogether::Quotas::Types::MediaStorage.visible_for?(quota)).to be true
    end

    it 'hides an LLM token row with a zero effective limit' do
      quota = BetterTogether::Quota.create!(owner: person, quota_type: 'ai_translation_tokens', limit: 0,
                                            period: 'monthly')

      expect(BetterTogether::Quotas::Types::AiTranslationTokens.visible_for?(quota)).to be false
    end

    it 'shows an LLM token row with a limit above zero' do
      quota = BetterTogether::Quota.create!(owner: person, quota_type: 'ai_translation_tokens', limit: 50_000,
                                            period: 'monthly')

      expect(BetterTogether::Quotas::Types::AiTranslationTokens.visible_for?(quota)).to be true
    end

    it 'shows an LLM token row whose zero limit is raised by an active grant' do
      quota = BetterTogether::Quota.create!(owner: person, quota_type: 'ai_translation_tokens', limit: 0,
                                            period: 'monthly')
      create(:better_together_quota_grant, owner: person, quota_type: 'ai_translation_tokens', limit: 1_000)

      expect(BetterTogether::Quotas::Types::AiTranslationTokens.visible_for?(quota)).to be true
    end
  end

  describe 'reversible? defaults' do
    it 'defaults to false on the base class' do
      expect(described_class.reversible?).to be false
    end

    it 'media_storage overrides to true' do
      expect(BetterTogether::Quotas::Types::MediaStorage.reversible?).to be true
    end

    it 'ai_translation_tokens leaves the false default' do
      expect(BetterTogether::Quotas::Types::AiTranslationTokens.reversible?).to be false
    end
  end
end
