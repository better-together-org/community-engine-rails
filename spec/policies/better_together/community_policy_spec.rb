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

    context 'when user is a platform steward' do
      let(:user) { BetterTogether::User.find_by(email: 'steward@example.test') }

      before do
        # Ensure the test platform manager is set up
        configure_host_platform

        platform = BetterTogether::Platform.first
        role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
               BetterTogether::Role.find_by(identifier: 'platform_manager')
        manager = find_or_create_test_user('steward@example.test', 'SecureTest123!@#', :platform_steward)

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

    context 'when community is private and an authorized robot has private-content scope' do
      let(:community) { create(:better_together_community, privacy: 'private') }
      let(:user) do
        create(
          :robot,
          settings: {
            bot_access_enabled: true,
            bot_access_scopes: %w[read_private_content],
            bot_access_token_digest: BetterTogether::Robot.bot_access_token_digest('token')
          }
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

    context 'when community is community scoped and user is a member' do
      let(:community) { create(:better_together_community, privacy: 'community') }
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

    context 'when community is community scoped and user is signed in but not a member' do
      let(:community) { create(:better_together_community, privacy: 'community') }
      let(:user) { create(:better_together_user) }

      it 'does not allow viewing' do
        expect(policy.show?).to be false
      end
    end

    context 'when community is community scoped and user is a guest' do
      let(:community) { create(:better_together_community, privacy: 'community') }
      let(:user) { nil }

      it 'does not allow viewing' do
        expect(policy.show?).to be false
      end
    end
  end

  describe 'Scope' do
    let!(:public_community) { create(:better_together_community, privacy: 'public') }
    let!(:community_scoped_community) { create(:better_together_community, privacy: 'community') }

    it 'includes community-scoped communities for members' do
      user = create(:better_together_user)
      member_role = BetterTogether::Role.find_by(identifier: 'community_member')
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community_scoped_community,
        member: user.person,
        role: member_role
      )

      resolved = described_class::Scope.new(user, BetterTogether::Community).resolve

      expect(resolved).to include(public_community, community_scoped_community)
    end

    it 'excludes community-scoped communities for signed-in non-members' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::Community).resolve

      expect(resolved).to include(public_community)
      expect(resolved).not_to include(community_scoped_community)
    end

    it 'excludes community-scoped communities for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Community).resolve

      expect(resolved).to include(public_community)
      expect(resolved).not_to include(community_scoped_community)
    end

    it 'includes private and community-scoped communities for a private-scope robot' do
      private_community = create(:better_together_community, privacy: 'private')
      robot = create(
        :robot,
        settings: {
          bot_access_enabled: true,
          bot_access_scopes: %w[read_private_content],
          bot_access_token_digest: BetterTogether::Robot.bot_access_token_digest('token')
        }
      )

      resolved = described_class::Scope.new(robot, BetterTogether::Community).resolve

      expect(resolved).to include(public_community, community_scoped_community, private_community)
    end
  end
end
