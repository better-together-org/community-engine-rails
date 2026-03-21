# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::Registry do
  describe '.entries' do
    it 'defines the current indexed model inventory explicitly' do
      expect(described_class.entries.map(&:model_name)).to eq(
        [
          'BetterTogether::Page',
          'BetterTogether::Post'
        ]
      )
    end
  end

  describe '.models' do
    it 'returns the indexed model classes' do
      expect(described_class.models).to eq([BetterTogether::Page, BetterTogether::Post])
      expect(described_class.models).not_to include(BetterTogether::Event)
    end
  end

  describe '.unmanaged_searchable_models' do
    it 'is empty when every searchable model is explicitly accounted for' do
      expect(described_class.unmanaged_searchable_models).to be_empty
    end
  end
end
