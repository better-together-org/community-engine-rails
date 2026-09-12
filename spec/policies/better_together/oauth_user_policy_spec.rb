# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthUserPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:other_user) { create(:better_together_user) }

  it 'inherits from UserPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::UserPolicy)
  end

  describe '#create?' do
    it 'always returns false (inherited from UserPolicy)' do
      expect(described_class.new(user, BetterTogether::OauthUser).create?).to be false
    end
  end

  describe '#destroy?' do
    it 'always returns false (inherited from UserPolicy)' do
      expect(described_class.new(user, other_user).destroy?).to be false
    end
  end

  describe '#show?' do
    it 'allows a user to view themselves' do
      expect(described_class.new(user, user).show?).to be true
    end

    it 'denies viewing another user without manage permissions' do
      expect(described_class.new(user, other_user).show?).to be false
    end
  end

  describe 'Scope' do
    it 'inherits from UserPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::UserPolicy::Scope)
    end
  end
end
