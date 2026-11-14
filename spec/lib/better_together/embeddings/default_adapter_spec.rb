# frozen_string_literal: true

require 'rails_helper'
require 'better_together/embeddings/default_adapter'

RSpec.describe BetterTogether::Embeddings::DefaultAdapter do
  let(:tokens_class) { Class.new { def input; end } }
  let(:response_class) do
    Class.new do
      def vectors; end
      def model; end
      def tokens; end
    end
  end

  describe '#call' do
    it 'embeds text via RubyLLM and serializes the vectors, model, tokens, and provider' do
      tokens = instance_double(tokens_class, input: 7)
      response = instance_double(response_class,
                                 vectors: [0.1, 0.2, 0.3],
                                 model: 'text-embedding-3-small',
                                 tokens:)
      allow(RubyLLM).to receive(:embed).and_return(response)

      result = described_class.new.call(
        'hello world',
        provider: 'openai',
        model: 'text-embedding-3-small',
        dimensions: 3,
        assume_model_exists: true
      )

      expect(RubyLLM).to have_received(:embed).with(
        'hello world',
        model: 'text-embedding-3-small',
        provider: :openai,
        dimensions: 3,
        assume_model_exists: true
      )
      expect(result[:vectors]).to eq([0.1, 0.2, 0.3])
      expect(result[:model]).to eq('text-embedding-3-small')
      expect(result[:prompt_tokens]).to eq(7)
      expect(result[:provider]).to eq('openai')
      expect(result[:raw_response]).to eq(response)
    end

    it 'omits optional RubyLLM.embed keywords that were not supplied' do
      tokens = instance_double(tokens_class, input: nil)
      response = instance_double(response_class, vectors: [0.1], model: 'text-embedding-3-small', tokens:)
      allow(RubyLLM).to receive(:embed).and_return(response)

      result = described_class.new.call('hello')

      expect(RubyLLM).to have_received(:embed).with('hello')
      expect(result[:prompt_tokens]).to eq(0)
      expect(result[:provider]).to be_nil
    end
  end
end
