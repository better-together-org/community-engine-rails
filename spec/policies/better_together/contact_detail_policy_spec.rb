# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContactDetailPolicy, type: :policy do
  let(:user) { create(:better_together_user) }

  describe '#create?' do
    it 'returns true for any authenticated user' do
      expect(described_class.new(user, BetterTogether::ContactDetail).create?).to be true
    end

    it 'returns true even for guest (nil user)' do
      expect(described_class.new(nil, BetterTogether::ContactDetail).create?).to be true
    end
  end

  describe '#destroy?' do
    it 'returns true for any authenticated user' do
      expect(described_class.new(user, BetterTogether::ContactDetail).destroy?).to be true
    end

    it 'returns true even for guest (nil user)' do
      expect(described_class.new(nil, BetterTogether::ContactDetail).destroy?).to be true
    end
  end

  describe 'Scope' do
    it 'inherits from PlatformRecordPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::PlatformRecordPolicy::Scope)
    end
  end
end
