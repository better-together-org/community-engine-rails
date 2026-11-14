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

    before { BetterTogether::Robot.update_all(active: false) } # rubocop:disable Rails/SkipsModelValidations

    it 'always offers media_storage' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return(nil)

      expect(described_class.available_keys(platform)).to include('media_storage')
    end

    it 'hides LLM usage tokens with no OpenAI token and no robot' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return(nil)

      expect(described_class.available_keys(platform)).not_to include('ai_translation_tokens')
    end

    it 'offers LLM usage tokens with an OpenAI token' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return('sk-test')

      expect(described_class.available_keys(platform)).to include('ai_translation_tokens')
    end

    it 'offers LLM usage tokens when an active robot is available' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return(nil)
      create(:better_together_robot, platform: nil, active: true)

      expect(described_class.available_keys(platform)).to include('ai_translation_tokens')
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
