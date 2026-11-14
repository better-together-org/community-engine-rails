# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FeatureAccessGrantPolicy, type: :policy do
  # The platform_manager trait creates membership on the host platform.
  # FeatureAccessGrant factory also targets the host platform by default.
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }
  let(:grant) { create(:better_together_feature_access_grant) }

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, grant).index?).to be false
    end

    it 'denies users who do not manage the target platform' do
      expect(described_class.new(normal_user, grant).index?).to be false
    end

    it 'allows managers of the grant\'s platform' do
      expect(described_class.new(manager_user, grant).index?).to be true
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, grant).create?).to be false
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, grant).create?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, grant).create?).to be true
    end
  end

  describe '#update?' do
    it 'denies guests' do
      expect(described_class.new(nil, grant).update?).to be false
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, grant).update?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, grant).update?).to be true
    end
  end

  describe '#destroy?' do
    it 'denies guests' do
      expect(described_class.new(nil, grant).destroy?).to be false
    end

    it 'denies non-managers' do
      expect(described_class.new(normal_user, grant).destroy?).to be false
    end

    it 'allows platform managers' do
      expect(described_class.new(manager_user, grant).destroy?).to be true
    end
  end
end
