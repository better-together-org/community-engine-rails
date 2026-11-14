# frozen_string_literal: true

require 'rails_helper'
require 'better_together/llm/default_adapter'

RSpec.describe BetterTogether::Llm::DefaultAdapter do
  describe '#call' do
    it 'builds a RubyLLM chat with the expected OpenAI provider and model path' do
      chat_class = Class.new do
        def with_instructions(_value); end
        def with_temperature(_value); end
        def with_max_output_tokens(_value); end
        def ask(_prompt); end
      end
      tokens_class = Class.new do
        def input; end
        def output; end
      end
      response_class = Class.new do
        def content; end
        def model; end
        def tokens; end
      end
      chat = instance_double(chat_class)
      tokens = instance_double(tokens_class, input: 12, output: 4)
      response = instance_double(response_class,
                                 content: 'Bonjour',
                                 model: 'gpt-4o-mini-2024-07-18',
                                 tokens:)

      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive_messages(
        with_instructions: chat,
        with_temperature: chat,
        with_max_output_tokens: chat
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
      expect(chat).to have_received(:with_max_output_tokens).with(1000)
      expect(result[:content]).to eq('Bonjour')
      expect(result[:provider]).to eq('openai')
      expect(result[:model]).to eq('gpt-4o-mini-2024-07-18')
      expect(result[:prompt_tokens]).to eq(12)
      expect(result[:completion_tokens]).to eq(4)
    end
  end
end
