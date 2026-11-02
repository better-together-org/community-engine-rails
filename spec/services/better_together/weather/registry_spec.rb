# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Registry do
  after { described_class.reset! }

  it 'knows the Environment Canada adapter' do
    expect(described_class.keys).to include('environment_canada')
    expect(described_class.build('environment_canada'))
      .to be_a(BetterTogether::Weather::Adapters::EnvironmentCanada)
  end

  it 'raises for unknown adapters' do
    expect { described_class.build('nope') }.to raise_error(described_class::UnknownAdapter)
  end

  it 'lets a host register another adapter' do
    stub_const('FakeWeatherAdapter', Class.new(BetterTogether::Weather::Adapters::Base))
    described_class.register('fake', 'FakeWeatherAdapter')

    expect(described_class.registered?('fake')).to be(true)
    expect(described_class.build('fake', { a: 1 }).config[:a]).to eq(1)
  end

  it 'reports no capabilities for the base adapter and raises on unimplemented fetches' do
    adapter = BetterTogether::Weather::Adapters::Base.new
    expect(adapter.supports?(:current)).to be(false)
    expect { adapter.fetch_snapshot(nil) }.to raise_error(NotImplementedError)
  end
end
