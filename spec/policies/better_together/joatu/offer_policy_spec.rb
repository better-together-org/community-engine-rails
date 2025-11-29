# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::OfferPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:manager_user)   { create(:better_together_user, :platform_manager) }
  let(:normal_user)    { create(:better_together_user) }

  let(:offer) { create(:better_together_joatu_offer, creator: creator_person) }

  describe '#index?' do
    it { expect(described_class.new(normal_user, offer).index?).to be true }
    it { expect(described_class.new(nil, offer).index?).to be false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, offer).show?).to be true }
    it { expect(described_class.new(nil, offer).show?).to be false }
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, offer).create?).to be true }
    it { expect(described_class.new(nil, offer).create?).to be false }
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).update?).to be true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, offer).update?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).destroy?).to be true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, offer).destroy?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).destroy?).to be false
    end
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Offer).resolve }

    let!(:offer1) { offer } # rubocop:todo RSpec/IndexedLet
    let!(:offer2) { create(:better_together_joatu_offer) } # rubocop:todo RSpec/IndexedLet

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'authenticated user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes all offers' do
        expect(resolved).to include(offer1, offer2)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
