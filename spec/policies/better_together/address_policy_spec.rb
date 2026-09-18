# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AddressPolicy, type: :policy do
  it 'inherits from ContactDetailPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::ContactDetailPolicy)
  end

  describe '#create?' do
    it 'returns true (inherited ContactDetailPolicy override)' do
      user = create(:better_together_user)
      expect(described_class.new(user, BetterTogether::Address).create?).to be true
    end
  end

  describe '#destroy?' do
    it 'returns true (inherited ContactDetailPolicy override)' do
      expect(described_class.new(nil, BetterTogether::Address).destroy?).to be true
    end
  end

  describe 'Scope' do
    let(:steward_user) { create(:better_together_user, :platform_steward) }
    let(:normal_user) { create(:better_together_user) }

    it 'inherits from ContactDetailPolicy::Scope' do
      expect(described_class::Scope.superclass).to eq(BetterTogether::ContactDetailPolicy::Scope)
    end

    it 'resolves without error for a platform manager' do
      expect do
        described_class::Scope.new(steward_user, BetterTogether::Address).resolve
      end.not_to raise_error
    end

    it 'resolves without error for a normal user' do
      expect do
        described_class::Scope.new(normal_user, BetterTogether::Address).resolve
      end.not_to raise_error
    end
  end
end
