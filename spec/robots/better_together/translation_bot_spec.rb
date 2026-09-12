# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TranslationBot do
  describe '#translate' do
    let(:platform) { create(:platform) }
    let!(:robot) do
      create(:robot,
             :global,
             identifier: 'translation',
             provider: 'openai',
             default_model: nil,
             system_prompt: 'Translate without adding commentary.')
    end

    before do
      allow(BetterTogether).to receive(:llm_chat).and_return(
        content: 'Hola',
        model: BetterTogether::Robot::DEFAULT_CHAT_MODEL,
        prompt_tokens: 10,
        completion_tokens: 3
      )
    end

    it 'routes translation through llm_chat with the OpenAI provider and fallback model defaults' do
      translated = described_class.new(platform:).translate('Hello', source_locale: 'en', target_locale: 'es')

      expect(translated).to eq('Hola')
      expect(BetterTogether).to have_received(:llm_chat).with(
        prompt: 'Translate the following text from en to es: Hello',
        system_prompt: 'Translate without adding commentary.',
        model: BetterTogether::Robot::DEFAULT_CHAT_MODEL,
        provider: 'openai',
        adapter_name: 'openai',
        temperature: 0.1,
        max_tokens: 1000,
        assume_model_exists: false,
        metadata: {
          robot_id: robot.id,
          robot_identifier: 'translation',
          platform_id: nil
        }
      )
    end
  end
end
