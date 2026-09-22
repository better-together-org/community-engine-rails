# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::CommunityMapPolicy, type: :policy do
  it 'inherits from Geography::MapPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::Geography::MapPolicy)
  end

  describe 'Scope' do
    it 'inherits from MapPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::Geography::MapPolicy::Scope)
    end
  end
end
