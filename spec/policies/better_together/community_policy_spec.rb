# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommunityPolicy do
  subject(:policy) { described_class.new(user, community) }

  let(:community) { create(:better_together_community) }
  let(:user) { nil }

  describe '#view_members?' do
    context 'when user is not authenticated' do
      let(:user) { nil }

      it 'does not allow viewing members' do
        expect(policy.view_members?).to be false
      end
    end

    context 'when user is authenticated but not a member' do
      let(:user) { create(:better_together_user) }

      it 'does not allow viewing members' do
        expect(policy.view_members?).to be false
      end
    end

    context 'when user is a community member' do
      let(:user) { create(:better_together_user) }
      let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

      before do
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: member_role
        )
      end

      it 'allows viewing members' do
        expect(policy.view_members?).to be true
      end
    end

    context 'when user is the community creator' do
      let(:user) { create(:better_together_user) }
      let(:community) { create(:better_together_community, creator: user.person) }

      it 'allows viewing members' do
        expect(policy.view_members?).to be true
      end
    end

    context 'when user is a platform manager' do
      # Platform manager setup will happen automatically with automatic configuration
      let(:user) { BetterTogether::User.find_by(email: 'manager@example.test') }

      before do
        # Ensure the test platform manager is set up
        configure_host_platform

        platform = BetterTogether::Platform.first
        role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        manager = find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)

        if platform && role && manager.person
          BetterTogether::PersonPlatformMembership.find_or_create_by!(
            member: manager.person,
            joinable: platform,
            role: role
          )
        end
      end

      it 'allows viewing members' do
        expect(policy.view_members?).to be true
      end
    end

    context 'when user is a community coordinator' do
      let(:user) { create(:better_together_user) }
      let(:coordinator_role) { BetterTogether::Role.find_by(identifier: 'community_coordinator') }

      before do
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: coordinator_role
        )
      end

      it 'allows viewing members' do
        expect(policy.view_members?).to be true
      end
    end
  end

  describe '#show?' do
    context 'when community is public' do
      let(:community) { create(:better_together_community, privacy: 'public') }

      it 'allows viewing' do
        expect(policy.show?).to be true
      end
    end

    context 'when community is private and user is not authenticated' do
      let(:community) { create(:better_together_community, privacy: 'private') }
      let(:user) { nil }

      it 'does not allow viewing' do
        expect(policy.show?).to be false
      end
    end

    context 'when community is private and user is a member' do
      let(:community) { create(:better_together_community, privacy: 'private') }
      let(:user) { create(:better_together_user) }
      let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

      before do
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: member_role
        )
      end

      it 'allows viewing' do
        expect(policy.show?).to be true
      end
    end

    context 'when community is private and user is the creator' do
      let(:user) { create(:better_together_user) }
      let(:community) { create(:better_together_community, privacy: 'private', creator: user.person) }

      it 'allows viewing' do
        expect(policy.show?).to be true
      end
    end
  end
end
