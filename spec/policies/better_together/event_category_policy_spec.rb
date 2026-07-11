# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventCategoryPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  it 'inherits from CategoryPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::CategoryPolicy)
  end

  describe '#index?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::EventCategory).index?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::EventCategory).index?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::EventCategory).index?).to be false
    end
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::EventCategory).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::EventCategory).create?).to be false
    end
  end

  describe 'Scope' do
    it 'inherits from CategoryPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::CategoryPolicy::Scope)
    end
  end
end
