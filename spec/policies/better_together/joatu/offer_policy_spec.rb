# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::OfferPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:steward_user)   { create(:better_together_user, :platform_steward) }
  let(:normal_user)    { create(:better_together_user) }

  let(:offer) { create(:better_together_joatu_offer, creator: creator_person, privacy: 'private') }

  describe '#index?' do
    it { expect(described_class.new(normal_user, offer).index?).to be true }
    it { expect(described_class.new(nil, offer).index?).to be false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, offer).show?).to be false }
    it { expect(described_class.new(nil, offer).show?).to be false }

    it 'allows viewing a public offer' do
      offer.update_column(:privacy, 'public')
      expect(described_class.new(normal_user, offer).show?).to be true
    end
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, offer).create?).to be true }
    it { expect(described_class.new(nil, offer).create?).to be false }
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).update?).to be true
    end

    it 'allows a steward' do
      expect(described_class.new(steward_user, offer).update?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, offer).destroy?).to be true
    end

    it 'allows a steward' do
      expect(described_class.new(steward_user, offer).destroy?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, offer).destroy?).to be false
    end
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Offer).resolve }

    let!(:owned_private_offer) { offer } # rubocop:todo RSpec/IndexedLet
    let!(:public_offer) do # rubocop:todo RSpec/IndexedLet
      create(:better_together_joatu_offer, privacy: 'private').tap { |offer_record| offer_record.update_column(:privacy, 'public') }
    end
    let!(:other_private_offer) { create(:better_together_joatu_offer, privacy: 'private') } # rubocop:todo RSpec/IndexedLet

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'authenticated user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes public offers only when the user is unrelated' do
        expect(resolved).to include(public_offer)
        expect(resolved).not_to include(owned_private_offer)
        expect(resolved).not_to include(other_private_offer)
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
