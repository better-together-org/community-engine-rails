# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe BetterTogether do
  around do |example|
    original_registry = described_class.adapter_registry
    described_class.adapter_registry = BetterTogether::AdapterRegistry.new
    example.run
    described_class.adapter_registry = original_registry
  end

  describe '.register_adapter' do
    let(:exception) { StandardError.new('boom') }
    let(:context) { { request_id: 'req-123', controller: 'pages', action: 'show' } }

    it 'dispatches to all registered providers for a subsystem' do
      first_adapter = instance_double(Proc)
      second_adapter = instance_double(Proc)
      allow(first_adapter).to receive(:call)
      allow(second_adapter).to receive(:call)

      described_class.register_adapter(:publishing, :ce, first_adapter)
      described_class.register_adapter(:publishing, :discourse, second_adapter)

      described_class.dispatch_to_adapters(:publishing, slug: 'plans/overview', content: 'hello')

      expect(first_adapter).to have_received(:call).with(slug: 'plans/overview', content: 'hello')
      expect(second_adapter).to have_received(:call).with(slug: 'plans/overview', content: 'hello')
    end

    it 'keeps the error-reporting compatibility wrapper on top of the generic registry' do
      adapter = instance_double(Proc)
      allow(adapter).to receive(:call)

      described_class.register_error_reporter(:sentry, adapter)
      described_class.report_error(exception, context:)

      expect(adapter).to have_received(:call).with(exception, context:)
      expect(described_class.adapters_for(:error_reporting).map { |entry| entry[:name] }).to eq([:sentry])
    end

    it 'falls back to Rails.error.report when no error adapters are registered' do
      rails_error = instance_double(ActiveSupport::ErrorReporter)
      allow(Rails).to receive(:error).and_return(rails_error)
      allow(rails_error).to receive(:report)

      described_class.report_error(exception, context:)

      expect(rails_error).to have_received(:report).with(
        exception,
        handled: true,
        severity: :error,
        context:
      )
    end

    it 'routes llm requests through a named adapter when one is registered' do
      adapter = instance_double(Proc)
      allow(adapter).to receive(:call).and_return(content: 'Bonjour')

      described_class.register_llm_adapter(:ollama, adapter)

      result = described_class.llm_chat(
        prompt: 'Hello',
        provider: 'ollama',
        model: 'llama3.2'
      )

      expect(result).to eq(content: 'Bonjour')
      expect(adapter).to have_received(:call).with(prompt: 'Hello', provider: 'ollama', model: 'llama3.2')
    end

    it 'routes embedding requests through a named adapter when one is registered' do
      adapter = instance_double(Proc)
      allow(adapter).to receive(:call).and_return(vectors: [0.1, 0.2])

      described_class.register_embedding_adapter(:borgberry, adapter)

      result = described_class.embed_text('hello', provider: 'borgberry', model: 'embed-small')

      expect(result).to eq(vectors: [0.1, 0.2])
      expect(adapter).to have_received(:call).with('hello', provider: 'borgberry', model: 'embed-small')
    end
  end

  describe '.llm_available?' do
    let(:platform) { create(:platform) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('BETTER_TOGETHER_LLM_PROVIDER', 'openai').and_return('openai')
      create(:robot, :global, identifier: 'translation', provider: 'openai', default_model: nil)
    end

    it 'returns true for the translation robot when OpenAI credentials are present' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-openai-key')
      allow(ENV).to receive(:fetch).with('OPENAI_ACCESS_TOKEN', nil).and_return(nil)

      expect(described_class.llm_available?(identifier: 'translation', platform:)).to be(true)
    end

    it 'returns false for the translation robot when OpenAI credentials are absent' do
      allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
      allow(ENV).to receive(:fetch).with('OPENAI_ACCESS_TOKEN', nil).and_return(nil)

      expect(described_class.llm_available?(identifier: 'translation', platform:)).to be(false)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
