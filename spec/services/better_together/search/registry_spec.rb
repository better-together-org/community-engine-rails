# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::Registry do
  describe '.entries' do
    it 'returns the current searchable model inventory from the shared concern contract' do
      expect(described_class.entries.map(&:model_name)).to eq(
        [
          'BetterTogether::CallForInterest',
          'BetterTogether::Checklist',
          'BetterTogether::Community',
          'BetterTogether::Event',
          'BetterTogether::Joatu::Offer',
          'BetterTogether::Joatu::Request',
          'BetterTogether::Page',
          'BetterTogether::Post'
        ]
      )
    end
  end

  describe '.models' do
    it 'returns the indexed model classes' do
      expect(described_class.models).to include(
        BetterTogether::CallForInterest,
        BetterTogether::Checklist,
        BetterTogether::Community,
        BetterTogether::Event,
        BetterTogether::Page,
        BetterTogether::Post,
        BetterTogether::Joatu::Offer,
        BetterTogether::Joatu::Request
      )
    end
  end

  describe '.unmanaged_searchable_models' do
    it 'is empty when every searchable model is explicitly accounted for' do
      expect(described_class.unmanaged_searchable_models).to be_empty
    end
  end

  describe '.global_search_models' do
    it 'still excludes models that are not marked as globally searchable' do
      expect(described_class.global_search_models).not_to include(BetterTogether::PersonLinkedSeed)
    end
  end
end
