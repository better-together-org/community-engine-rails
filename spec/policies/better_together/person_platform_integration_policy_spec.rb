# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegrationPolicy, type: :policy do
  let(:user) { create(:better_together_user) }
  let(:other_user) { create(:better_together_user) }
  let(:own_integration) { create(:better_together_person_platform_integration, user: user) }
  let(:other_integration) { create(:better_together_person_platform_integration, user: other_user) }

  describe '#index?' do
    it 'allows authenticated user to see the index' do
      expect(described_class.new(user, BetterTogether::PersonPlatformIntegration).index?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::PersonPlatformIntegration).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows user to view their own integration' do
      expect(described_class.new(user, own_integration).show?).to be true
    end

    it 'denies user from viewing another user\'s integration' do
      expect(described_class.new(user, other_integration).show?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, own_integration).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows authenticated user' do
      expect(described_class.new(user, BetterTogether::PersonPlatformIntegration).create?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::PersonPlatformIntegration).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows user to update their own integration' do
      expect(described_class.new(user, own_integration).update?).to be true
    end

    it 'denies user from updating another user\'s integration' do
      expect(described_class.new(user, other_integration).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows user to destroy their own integration' do
      expect(described_class.new(user, own_integration).destroy?).to be true
    end

    it 'denies user from destroying another user\'s integration' do
      expect(described_class.new(user, other_integration).destroy?).to be false
    end
  end

  describe 'Scope' do
    it 'resolves to only the current user\'s integrations' do
      own_integration
      other_integration
      resolved = described_class::Scope.new(user, BetterTogether::PersonPlatformIntegration).resolve
      expect(resolved).to include(own_integration)
      expect(resolved).not_to include(other_integration)
    end
  end
end
