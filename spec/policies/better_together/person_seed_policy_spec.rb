# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonSeedPolicy do
  let(:user)        { create(:better_together_user, :confirmed) }
  let(:agent)       { user.person }
  let(:other_user)  { create(:better_together_user, :confirmed) }
  let(:other_agent) { other_user.person }

  # Seed owned via creator_id
  let(:creator_seed) do
    create(:better_together_seed, :created_by_person, creator: agent)
  end

  # Seed owned via seedable polymorphic association
  let(:seedable_seed) do
    create(:better_together_seed, :owned_as_seedable, person: agent)
  end

  # Seed belonging to a different person
  let(:other_seed) do
    create(:better_together_seed, :created_by_person, creator: other_agent)
  end

  # Seed with no owner at all
  let(:unowned_seed) { create(:better_together_seed) }

  # ----------------------------------------------------------------
  # index?
  # ----------------------------------------------------------------
  describe '#index?' do
    it 'allows authenticated users' do
      expect(described_class.new(user, BetterTogether::Seed).index?).to be true
    end

    it 'denies unauthenticated (nil user)' do
      expect(described_class.new(nil, BetterTogether::Seed).index?).to be false
    end
  end

  # ----------------------------------------------------------------
  # export?
  # ----------------------------------------------------------------
  describe '#export?' do
    it 'allows authenticated users' do
      expect(described_class.new(user, BetterTogether::Seed).export?).to be true
    end

    it 'denies unauthenticated (nil user)' do
      expect(described_class.new(nil, BetterTogether::Seed).export?).to be false
    end
  end

  # ----------------------------------------------------------------
  # show?
  # ----------------------------------------------------------------
  describe '#show?' do
    it 'allows when creator_id matches agent' do
      expect(described_class.new(user, creator_seed).show?).to be true
    end

    it 'allows when seedable matches agent' do
      expect(described_class.new(user, seedable_seed).show?).to be true
    end

    it 'denies for another person\'s seed' do
      expect(described_class.new(user, other_seed).show?).to be false
    end

    it 'denies for an unowned seed' do
      expect(described_class.new(user, unowned_seed).show?).to be false
    end

    it 'denies for unauthenticated user' do
      expect(described_class.new(nil, creator_seed).show?).to be false
    end
  end

  # ----------------------------------------------------------------
  # destroy?
  # ----------------------------------------------------------------
  describe '#destroy?' do
    it 'allows when creator_id matches agent' do
      expect(described_class.new(user, creator_seed).destroy?).to be true
    end

    it 'allows when seedable matches agent' do
      expect(described_class.new(user, seedable_seed).destroy?).to be true
    end

    it 'denies for another person\'s seed' do
      expect(described_class.new(user, other_seed).destroy?).to be false
    end

    it 'denies for unauthenticated user' do
      expect(described_class.new(nil, creator_seed).destroy?).to be false
    end
  end

  # ----------------------------------------------------------------
  # Scope
  # ----------------------------------------------------------------
  describe 'Scope#resolve' do
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Seed).resolve }

    before do
      creator_seed
      seedable_seed
      other_seed
      unowned_seed
    end

    it 'includes seeds where creator_id matches agent' do
      expect(resolved).to include(creator_seed)
    end

    it 'includes seeds where seedable matches agent' do
      expect(resolved).to include(seedable_seed)
    end

    it 'excludes seeds owned by another person' do
      expect(resolved).not_to include(other_seed)
    end

    it 'excludes unowned seeds' do
      expect(resolved).not_to include(unowned_seed)
    end

    it 'orders results by created_at descending' do
      expect(resolved.to_a).to eq(resolved.reorder(created_at: :desc).to_a)
    end

    context 'when unauthenticated (nil user)' do
      subject(:resolved) { described_class::Scope.new(nil, BetterTogether::Seed).resolve }

      it 'returns no seeds' do
        expect(resolved).to be_empty
      end
    end
  end
end
