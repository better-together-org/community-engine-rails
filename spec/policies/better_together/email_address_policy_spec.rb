# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EmailAddressPolicy, type: :policy do
  it 'inherits from ContactDetailPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::ContactDetailPolicy)
  end

  describe '#create?' do
    it 'returns true unconditionally (inherited from ContactDetailPolicy)' do
      expect(described_class.new(nil, nil).create?).to be true
    end
  end

  describe '#destroy?' do
    it 'returns true unconditionally (inherited from ContactDetailPolicy)' do
      expect(described_class.new(nil, nil).destroy?).to be true
    end
  end

  describe 'Scope' do
    it 'inherits from ContactDetailPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::ContactDetailPolicy::Scope)
    end
  end
end
