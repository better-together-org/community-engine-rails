# frozen_string_literal: true

require 'rails_helper'
require 'better_together/llm/default_adapter'

RSpec.describe BetterTogether::Llm::DefaultAdapter do
  describe '#call' do
    it 'builds a RubyLLM chat with the expected OpenAI provider and model path' do
      chat_class = Class.new do
        def with_instructions(_value); end
        def with_temperature(_value); end
        def with_params(_value); end
        def ask(_prompt); end
      end
      response_class = Class.new do
        def content; end
        def model_id; end
        def input_tokens; end
        def output_tokens; end
      end
      chat = instance_double(chat_class)
      response = instance_double(response_class,
                                 content: 'Bonjour',
                                 model_id: 'gpt-4o-mini-2024-07-18',
                                 input_tokens: 12,
                                 output_tokens: 4)

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive_messages(
        with_instructions: chat,
        with_temperature: chat,
        with_params: chat
      )
      allow(chat).to receive(:ask).with('Hello').and_return(response)

      result = described_class.new.call(
        prompt: 'Hello',
        provider: 'openai',
        model: BetterTogether::Robot::DEFAULT_CHAT_MODEL,
        system_prompt: 'Translate accurately.',
        temperature: 0.1,
        max_tokens: 1000
      )

      expect(RubyLLM).to have_received(:chat).with(
        model: BetterTogether::Robot::DEFAULT_CHAT_MODEL,
        provider: :openai
      )
      expect(result[:content]).to eq('Bonjour')
      expect(result[:provider]).to eq('openai')
      expect(result[:model]).to eq('gpt-4o-mini-2024-07-18')
    end
  end
end
