# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AdapterRegistry do
  subject(:registry) { described_class.new }

  let(:exception) { StandardError.new('boom') }
  let(:context) { { request_id: 'req-123' } }

  it 'registers multiple adapters under the same subsystem' do
    first_adapter = instance_double(Proc)
    second_adapter = instance_double(Proc)
    allow(first_adapter).to receive(:call)
    allow(second_adapter).to receive(:call)

    registry.register(:error_reporting, :first, first_adapter)
    registry.register(:error_reporting, :second, second_adapter)

    registry.dispatch(:error_reporting, exception, context:)

    expect(first_adapter).to have_received(:call).with(exception, context:)
    expect(second_adapter).to have_received(:call).with(exception, context:)
  end

  it 'replaces an existing named adapter for the same subsystem' do
    first_adapter = instance_double(Proc)
    second_adapter = instance_double(Proc)
    allow(first_adapter).to receive(:call)
    allow(second_adapter).to receive(:call)

    registry.register(:metrics, :google, first_adapter)
    registry.register(:metrics, :google, second_adapter)

    registry.dispatch(:metrics, name: 'page_views')

    expect(first_adapter).not_to have_received(:call)
    expect(second_adapter).to have_received(:call).with(name: 'page_views')
  end

  it 'clears only the requested subsystem when asked' do
    error_adapter = instance_double(Proc)
    search_adapter = instance_double(Proc)
    allow(error_adapter).to receive(:call)
    allow(search_adapter).to receive(:call)

    registry.register(:error_reporting, :sentry, error_adapter)
    registry.register(:search, :ce, search_adapter)

    registry.clear!(:error_reporting)
    registry.dispatch(:search, query: 'welcome')

    expect(registry.adapters_for(:error_reporting)).to eq([])
    expect(search_adapter).to have_received(:call).with(query: 'welcome')
  end

  it 'can look up a specific named adapter for direct invocation' do
    adapter = ->(*) {}

    registry.register(:llm, :ollama, adapter)

    expect(registry.adapter_for(:llm, :ollama)).to eq(name: :ollama, adapter:)
  end
end
