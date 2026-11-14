# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::CountryPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:country) { create(:geography_country, protected: false) }
  let(:protected_country) { create(:geography_country, :protected) }

  describe '#index?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, country).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, country).index?).to be false
    end
  end

  describe '#create?' do
    it 'always returns false' do
      expect(described_class.new(user, BetterTogether::Geography::Country).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows authenticated user for an unprotected country' do
      expect(described_class.new(user, country).update?).to be true
    end

    it 'denies authenticated user for a protected country' do
      expect(described_class.new(user, protected_country).update?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, country).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows authenticated user for an unprotected country' do
      expect(described_class.new(user, country).destroy?).to be true
    end

    it 'denies authenticated user for a protected country' do
      expect(described_class.new(user, protected_country).destroy?).to be false
    end
  end
end
