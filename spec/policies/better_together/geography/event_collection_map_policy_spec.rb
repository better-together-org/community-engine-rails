# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::EventCollectionMapPolicy, type: :policy do
  it 'inherits from Geography::LocatableMapPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::Geography::LocatableMapPolicy)
  end

  describe 'Scope' do
    it 'inherits from LocatableMapPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::Geography::LocatableMapPolicy::Scope)
    end
  end
end
