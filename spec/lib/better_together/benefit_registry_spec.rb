# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BenefitRegistry do
  before { described_class.reset! }

  after { described_class.reset! }

  describe '.all' do
    it 'loads the shipped benefit_registry.yml and freezes the result' do
      expect(described_class.all).to be_frozen
      expect(described_class.keys).to include('event_registration')
    end
  end

  describe '.find' do
    it 'returns the entry for a known key' do
      entry = described_class.find('event_registration')

      expect(entry).to include(name: 'Event Registration Credit')
    end

    it 'returns nil for an unknown key' do
      expect(described_class.find('not_a_real_benefit')).to be_nil
    end

    it 'accepts a symbol or a string' do
      expect(described_class.find(:event_registration)).to eq(described_class.find('event_registration'))
    end
  end

  describe '.fetch' do
    it 'raises for an unknown key' do
      expect { described_class.fetch('not_a_real_benefit') }.to raise_error(KeyError)
    end
  end

  describe '.name_for' do
    it 'returns a placeholder for an unknown key' do
      expect(described_class.name_for('not_a_real_benefit')).to include('Unknown benefit')
    end
  end
end
