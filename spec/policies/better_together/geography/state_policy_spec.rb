# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::StatePolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:state) { create(:geography_state, protected: false) }
  let(:protected_state) { create(:geography_state, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, state).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, state).index?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::State).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected state' do
      expect(described_class.new(user, state).update?).to be true
    end

    it 'denies authenticated user for a protected state' do
      expect(described_class.new(user, protected_state).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected state' do
      expect(described_class.new(user, state).destroy?).to be true
    end

    it 'denies authenticated user for a protected state' do
      expect(described_class.new(user, protected_state).destroy?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, state).destroy?).to be false
    end
  end
end
