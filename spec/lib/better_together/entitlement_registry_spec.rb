# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EntitlementRegistry do
  before { described_class.reset! }

  after { described_class.reset! }

  describe '.all' do
    it 'loads the shipped entitlement_registry.yml and freezes the result' do
      expect(described_class.all).to be_frozen
      expect(described_class.keys).to include('hosted_access')
    end
  end

  describe '.find' do
    it 'returns the entry for a known key' do
      entry = described_class.find('hosted_access')

      expect(entry).to include(name: 'Hosted Platform Access', resolution: 'grant')
    end

    it 'returns nil for an unknown key' do
      expect(described_class.find('not_a_real_entitlement')).to be_nil
    end

    it 'accepts a symbol or a string' do
      expect(described_class.find(:hosted_access)).to eq(described_class.find('hosted_access'))
    end
  end

  describe '.fetch' do
    it 'raises for an unknown key' do
      expect { described_class.fetch('not_a_real_entitlement') }.to raise_error(KeyError)
    end
  end

  describe '.name_for' do
    it 'returns a placeholder for an unknown key' do
      expect(described_class.name_for('not_a_real_entitlement')).to include('Unknown entitlement')
    end
  end

  describe 'entry validation' do
    it 'raises for an entry with an unrecognized resolution mode' do
      allow(YAML).to receive(:safe_load_file).and_return(
        'entitlements' => [{ 'key' => 'bad_entry', 'name' => 'Bad', 'resolution' => 'not_a_mode' }]
      )

      expect { described_class.all }.to raise_error(ArgumentError, /invalid resolution/)
    end
  end
end
