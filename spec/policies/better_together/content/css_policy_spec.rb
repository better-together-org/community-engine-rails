# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::CssPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  it 'inherits from Content::BlockPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::Content::BlockPolicy)
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::Css).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Content::Css).create?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::Css).destroy?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Content::Css).destroy?).to be false
    end
  end

  describe 'Scope' do
    it 'inherits from BlockPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::Content::BlockPolicy::Scope)
    end
  end
end
