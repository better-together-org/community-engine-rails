# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TranslationBot do
  let(:robot) do
    build(
      :robot,
      :ollama,
      identifier: 'translation',
      system_prompt: 'Translate precisely and return only translated content.'
    )
  end

  describe '#translate' do
    before do
      allow(BetterTogether).to receive(:llm_chat).and_return(
        {
          content: 'Bonjour',
          model: 'llama3.2',
          prompt_tokens: 12,
          completion_tokens: 3
        }
      )
      allow(BetterTogether::Ai::Log::TranslationLoggerJob).to receive(:perform_later)
    end

    it 'routes translations through the llm adapter with robot context' do
      bot = described_class.new(robot:)

      result = bot.translate('Hello', source_locale: 'en', target_locale: 'fr')

      expect(result).to eq('Bonjour')
      expect(BetterTogether).to have_received(:llm_chat).with(
        hash_including(
          prompt: include('Translate the following text from en to fr: Hello'),
          system_prompt: 'Translate precisely and return only translated content.',
          provider: 'ollama',
          adapter_name: 'ollama',
          model: 'llama3.2',
          assume_model_exists: true
        )
      )
    end

    it 'preserves Trix attachments in translated content' do
      allow(BetterTogether).to receive(:llm_chat).and_return(
        {
          content: 'Bonjour TRIX_ATTACHMENT_PLACEHOLDER_0',
          model: 'llama3.2',
          prompt_tokens: 20,
          completion_tokens: 5
        }
      )

      content = '<p>Hello</p><figure data-trix-attachment="abc"></figure>'
      bot = described_class.new(robot:)

      result = bot.translate(content, source_locale: 'en', target_locale: 'fr')

      expect(result).to include('<figure data-trix-attachment="abc"></figure>')
    end

    it 'logs token usage from the adapter response when an initiator is present' do
      bot = described_class.new(robot:)
      initiator = instance_double(BetterTogether::Person)

      bot.translate('Hello', source_locale: 'en', target_locale: 'fr', initiator:)

      expect(BetterTogether::Ai::Log::TranslationLoggerJob).to have_received(:perform_later).with(
        hash_including(
          prompt_tokens: 12,
          completion_tokens: 3,
          model: 'llama3.2',
          initiator:
        )
      )
    end
  end
end
