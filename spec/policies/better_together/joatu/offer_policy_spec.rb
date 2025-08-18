# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::OfferPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:manager_user)   { create(:better_together_user, :platform_manager) }
  let(:normal_user)    { create(:better_together_user) }

  let(:offer) { create(:better_together_joatu_offer, creator: creator_person) }

  describe '#index?' do
    it { expect(described_class.new(normal_user, offer).index?).to eq true }
    it { expect(described_class.new(nil, offer).index?).to eq false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, offer).show?).to eq true }
    it { expect(described_class.new(nil, offer).show?).to eq false }
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, offer).create?).to eq true }
    it { expect(described_class.new(nil, offer).create?).to eq false }
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).update?).to eq true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, offer).update?).to eq true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).update?).to eq false
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).destroy?).to eq true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, offer).destroy?).to eq true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).destroy?).to eq false
    end
  end

  describe 'Scope' do
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Offer).resolve }

    let!(:offer1) { offer }
    let!(:offer2) { create(:better_together_joatu_offer) }

    context 'authenticated user' do
      let(:user) { normal_user }

      it 'includes all offers' do
        expect(resolved).to include(offer1, offer2)
      end
    end

    context 'guest' do
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
  end
end
