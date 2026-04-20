# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonCommunityMembershipPolicy, type: :policy do
  subject(:policy) { described_class.new(user, membership) }

  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let(:other_person) { other_user.person }
  let(:membership) { build_stubbed(:better_together_person_community_membership, member: person) }
  let(:community) { membership.joinable }

  before do
    allow(person).to receive(:permitted_to?).and_return(false)
    allow(other_person).to receive(:permitted_to?).and_return(false)
  end

  describe '#index?' do
    it 'allows users who can update community' do
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(true)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)
      expect(policy.index?).to be true
    end

    it 'allows platform managers' do
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(false)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(true)
      expect(policy.index?).to be true
    end

    it 'denies users without permissions' do
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(false)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)
      expect(policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'allows viewing own membership' do
      expect(policy.show?).to be true
    end

    it 'allows viewing another membership with update_community permission' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(true)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)
      expect(policy.show?).to be true
    end

    it 'allows viewing another membership as platform manager' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(false)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(true)
      expect(policy.show?).to be true
    end

    it 'denies viewing another membership without permission' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(false)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows users who can manage community members' do
      allow(person).to receive(:permitted_to?).with('manage_community_members', community).and_return(true)
      expect(policy.create?).to be true
    end

    it 'allows users who can manage community roles' do
      allow(person).to receive(:permitted_to?).with('manage_community_roles', community).and_return(true)
      expect(policy.create?).to be true
    end

    it 'denies users without permissions' do
      expect(policy.create?).to be false
    end
  end

  describe '#edit?' do
    it 'allows users who can manage community members' do
      allow(person).to receive(:permitted_to?).with('manage_community_members', community).and_return(true)
      expect(policy.edit?).to be true
    end

    it 'allows users who can manage community roles' do
      allow(person).to receive(:permitted_to?).with('manage_community_roles', community).and_return(true)
      expect(policy.edit?).to be true
    end

    it 'denies users without permissions' do
      expect(policy.edit?).to be false
    end
  end

  describe '#destroy?' do
    it 'denies destroying own membership even with permissions' do
      allow(person).to receive(:permitted_to?).with('manage_community_members', community).and_return(true)
      expect(policy.destroy?).to be false
    end

    it 'allows destroying another membership as community member manager' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('manage_community_members', other_membership.joinable).and_return(true)
      allow(other_person).to receive(:permitted_to?).with('manage_community_roles', other_membership.joinable).and_return(false)
      expect(policy.destroy?).to be true
    end

    it 'allows destroying another membership as community role manager' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('manage_community_roles', other_membership.joinable).and_return(true)
      allow(other_person).to receive(:permitted_to?).with('manage_community_roles', other_membership.joinable).and_return(false)
      expect(policy.destroy?).to be true
    end

    it 'denies destroying community role manager membership' do
      other_membership = build_stubbed(:better_together_person_community_membership, member: other_person)
      policy = described_class.new(user, other_membership)
      allow(person).to receive(:permitted_to?).with('manage_community_members', other_membership.joinable).and_return(true)
      allow(other_person).to receive(:permitted_to?).with('manage_community_roles', other_membership.joinable).and_return(true)
      expect(policy.destroy?).to be false
    end
  end

  describe 'Scope#resolve' do
    subject(:resolved_scope) { described_class::Scope.new(user, scope, **options).resolve }

    let(:scope) { BetterTogether::PersonCommunityMembership.all }
    let(:options) { {} }

    it 'returns none when user is not authenticated' do
      unauthenticated_scope = described_class::Scope.new(nil, scope, **options).resolve
      expect(unauthenticated_scope).to eq(BetterTogether::PersonCommunityMembership.none)
    end

    it 'returns only own memberships without manage permissions' do
      allow(person).to receive(:permitted_to?).with('update_community', nil).and_return(false)
      allow(person).to receive(:permitted_to?).with('manage_platform', nil).and_return(false)
      expect(resolved_scope.to_sql).to include('member_id')
    end
  end
end
