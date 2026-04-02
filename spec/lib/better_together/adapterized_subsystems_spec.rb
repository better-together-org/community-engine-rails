# frozen_string_literal: true

require 'rails_helper'

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
  end
end
