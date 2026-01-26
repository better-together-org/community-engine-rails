# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformMembershipPolicy, type: :policy do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:platform_manager_role) { BetterTogether::Role.find_by(identifier: 'platform_manager') }
  let(:analytics_viewer_role) do
    BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer',
                                 resource_type: 'BetterTogether::Platform')
  end

  let(:manager_user) { create(:better_together_user, :confirmed) }
  let(:manager_person) { manager_user.person }

  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_person) { regular_user.person }

  let(:target_person) { create(:better_together_person) }

  before do
    # Set up platform manager
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform,
      member: manager_person,
      role: platform_manager_role
    )
  end

  describe '#index?' do
    context 'when user has update_platform permission' do
      it 'allows access' do
        policy = described_class.new(manager_user, BetterTogether::PersonPlatformMembership)
        expect(policy.index?).to be true
      end
    end

    context 'when user lacks update_platform permission' do
      it 'denies access' do
        policy = described_class.new(regular_user, BetterTogether::PersonPlatformMembership)
        expect(policy.index?).to be false
      end
    end

    context 'when user is nil' do
      it 'denies access' do
        policy = described_class.new(nil, BetterTogether::PersonPlatformMembership)
        expect(policy.index?).to be false
      end
    end
  end

  describe '#create?' do
    let(:membership) do
      BetterTogether::PersonPlatformMembership.new(
        joinable: platform,
        member: target_person,
        role: analytics_viewer_role
      )
    end

    context 'when user has update_platform permission' do
      it 'allows creating memberships' do
        policy = described_class.new(manager_user, membership)
        expect(policy.create?).to be true
      end
    end

    context 'when user lacks update_platform permission' do
      it 'denies creating memberships' do
        policy = described_class.new(regular_user, membership)
        expect(policy.create?).to be false
      end
    end

    context 'when user is nil' do
      it 'denies creating memberships' do
        policy = described_class.new(nil, membership)
        expect(policy.create?).to be false
      end
    end
  end

  describe '#edit?' do
    let(:membership) do
      create(:better_together_person_platform_membership,
             joinable: platform,
             member: target_person,
             role: analytics_viewer_role)
    end

    context 'when user has update_platform permission' do
      it 'allows editing memberships' do
        policy = described_class.new(manager_user, membership)
        expect(policy.edit?).to be true
      end
    end

    context 'when user lacks update_platform permission' do
      it 'denies editing memberships' do
        policy = described_class.new(regular_user, membership)
        expect(policy.edit?).to be false
      end
    end
  end

  describe '#destroy?' do
    let(:regular_membership) do
      create(:better_together_person_platform_membership,
             joinable: platform,
             member: target_person,
             role: analytics_viewer_role)
    end

    context 'when user has update_platform permission' do
      it 'allows destroying the membership' do
        policy = described_class.new(manager_user, regular_membership)
        expect(policy.destroy?).to be true
      end
    end

    context 'when user lacks update_platform permission' do
      it 'denies destroying the membership' do
        policy = described_class.new(regular_user, regular_membership)
        expect(policy.destroy?).to be false
      end
    end

    context 'when trying to destroy own membership' do
      let(:membership) do
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: manager_person,
               role: analytics_viewer_role)
      end

      it 'denies destroying own membership' do
        policy = described_class.new(manager_user, membership)
        expect(policy.destroy?).to be false
      end
    end

    context 'when trying to destroy a platform manager membership' do
      let(:other_manager_user) { create(:better_together_user, :confirmed) }
      let(:other_manager_person) { other_manager_user.person }
      let(:membership) do
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: other_manager_person,
               role: platform_manager_role)
      end

      it 'denies destroying platform manager memberships' do
        policy = described_class.new(manager_user, membership)
        expect(policy.destroy?).to be false
      end
    end

    context 'when user is nil' do
      let(:membership) do
        create(:better_together_person_platform_membership,
               joinable: platform,
               member: target_person,
               role: analytics_viewer_role)
      end

      it 'denies destroying the membership' do
        policy = described_class.new(nil, membership)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe 'Scope' do
    let!(:first_membership) do
      create(:better_together_person_platform_membership,
             joinable: platform,
             member: regular_person,
             role: analytics_viewer_role)
    end
    let!(:second_membership) do
      create(:better_together_person_platform_membership,
             joinable: platform,
             member: target_person,
             role: analytics_viewer_role)
    end

    it 'returns all memberships' do
      scope = described_class::Scope.new(manager_user, BetterTogether::PersonPlatformMembership).resolve
      expect(scope).to include(first_membership, second_membership)
    end
  end
end
