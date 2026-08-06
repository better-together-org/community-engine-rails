# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommunityPolicy do
  subject(:policy) { described_class.new(user, community) }

  let(:community) { create(:better_together_community) }
  let(:user) { nil }

  describe '#create?' do
    subject(:policy) { described_class.new(user, BetterTogether::Community) }

    context 'when user is a platform manager' do
      let(:user) { create(:better_together_user, :confirmed, :platform_manager) }

      it 'allows creation without accepting the community creation agreement' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has accepted the community creation agreement' do
      let(:user) { create(:better_together_user, :confirmed) }

      before { grant_community_creation_agreement(user.person) }

      it 'allows creation' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has not accepted the community creation agreement' do
      let(:user) { create(:better_together_user, :confirmed) }

      it 'denies creation' do
        expect(policy.create?).to be false
      end
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it 'denies creation' do
        expect(policy.create?).to be false
      end
    end
  end

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
          role: member_role,
          status: 'active'
        )
      end

      it 'allows viewing members' do
        expect(policy.view_members?).to be true
      end
    end

    context 'when the membership is pending' do
      let(:user) { create(:better_together_user) }
      let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

      before do
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: member_role,
          status: 'pending'
        )
      end

      it 'does not allow viewing members' do
        expect(policy.view_members?).to be false
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
          membership = BetterTogether::PersonPlatformMembership.find_or_initialize_by(
            member: manager.person,
            joinable: platform,
            role: role
          )
          membership.status = 'active'
          membership.save!
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
          role: coordinator_role,
          status: 'active'
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
          role: member_role,
          status: 'active'
        )
      end

      it 'allows viewing' do
        expect(policy.show?).to be true
      end
    end

    context 'when community is private and user only has a pending membership' do
      let(:community) { create(:better_together_community, privacy: 'private') }
      let(:user) { create(:better_together_user) }
      let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

      before do
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: member_role,
          status: 'pending'
        )
      end

      it 'does not allow viewing' do
        expect(policy.show?).to be false
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
          role: member_role,
          status: 'active'
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

  describe '#manage_merchant_account?' do
    context 'when user can update the community but has no settings-tier permission' do
      let(:user) { create(:better_together_user) }
      let(:facilitator_role) { BetterTogether::Role.find_by(identifier: 'community_facilitator') }

      before do
        # This worktree's test database can carry a stale community_facilitator
        # permission set from an earlier seed run that AccessControlBuilder's
        # own reseed guard (`unless Role.exists?`) never refreshes once roles
        # already exist. Assign explicitly so this test reflects the role
        # definition actually in source, not whatever happens to be persisted.
        facilitator_role.assign_resource_permissions(
          %w[read_community list_community create_community update_community delete_community
             invite_community_members],
          sync: true
        )
        BetterTogether::PersonCommunityMembership.create!(
          joinable: community,
          member: user.person,
          role: facilitator_role,
          status: 'active'
        )
      end

      it 'allows managing the community' do
        expect(policy.update?).to be true
      end

      it 'denies payout-onboarding management' do
        expect(policy.manage_merchant_account?).to be false
      end
    end

    context 'when user is a platform steward' do
      let(:user) { BetterTogether::User.find_by(email: 'merchant-steward@example.test') }

      before do
        configure_host_platform
        platform = BetterTogether::Platform.first
        role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
               BetterTogether::Role.find_by(identifier: 'platform_manager')
        manager = find_or_create_test_user('merchant-steward@example.test', 'SecureTest123!@#', :platform_steward)

        next unless platform && role && manager.person

        membership = BetterTogether::PersonPlatformMembership.find_or_initialize_by(
          member: manager.person,
          joinable: platform,
          role: role
        )
        membership.status = 'active'
        membership.save!
      end

      it 'allows payout-onboarding management' do
        expect(policy.manage_merchant_account?).to be true
      end
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, community).manage_merchant_account?).to be false
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
        role: member_role,
        status: 'active'
      )

      resolved = described_class::Scope.new(user, BetterTogether::Community).resolve

      expect(resolved).to include(public_community, community_scoped_community)
    end

    it 'excludes community-scoped communities for pending members' do
      user = create(:better_together_user)
      member_role = BetterTogether::Role.find_by(identifier: 'community_member')
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community_scoped_community,
        member: user.person,
        role: member_role,
        status: 'pending'
      )

      resolved = described_class::Scope.new(user, BetterTogether::Community).resolve

      expect(resolved).to include(public_community)
      expect(resolved).not_to include(community_scoped_community)
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

  describe '.manageable_community_ids' do
    include InvitationTestHelpers

    let(:community_a) { create(:better_together_community, name: 'Community A') }
    let(:community_b) { create(:better_together_community, name: 'Community B') }
    let(:community_c) { create(:better_together_community, name: 'Community C') }
    let(:candidate_ids) { [community_a, community_b, community_c].map(&:id) }

    it 'returns no ids for a nil agent' do
      expect(described_class.manageable_community_ids(nil, candidate_ids)).to eq([])
    end

    it 'returns no ids when given an empty candidate list' do
      user = create(:better_together_user, :confirmed)
      expect(described_class.manageable_community_ids(user.person, [])).to eq([])
    end

    it 'returns every candidate id for a platform manager, matching policy(candidate).update?' do
      user = create(:better_together_user, :confirmed, :platform_manager)

      ids = described_class.manageable_community_ids(user.person, candidate_ids)

      expect(ids).to match_array(candidate_ids)
      [community_a, community_b, community_c].each do |candidate|
        expect(described_class.new(user, candidate).update?).to be(true)
      end
    end

    it 'returns only communities the agent holds a manage-capable role on, ' \
       'matching policy(candidate).update? per record' do
      user = create(:better_together_user, :confirmed)
      make_community_organizer(user, community_a)

      ids = described_class.manageable_community_ids(user.person, candidate_ids)

      expect(ids).to contain_exactly(community_a.id)
      expect(described_class.new(user, community_a).update?).to be(true)
      expect(described_class.new(user, community_b).update?).to be(false)
      expect(described_class.new(user, community_c).update?).to be(false)
    end

    it 'returns no ids for a user with no manage-capable role anywhere' do
      user = create(:better_together_user, :confirmed)

      expect(described_class.manageable_community_ids(user.person, candidate_ids)).to eq([])
    end

    it 'does not scale its query count with the number of candidates' do
      user = create(:better_together_user, :confirmed)
      make_community_organizer(user, community_a)

      count_queries = lambda do |ids|
        n = 0
        counter = lambda do |*, payload|
          n += 1 unless payload[:sql].start_with?('SCHEMA', 'TRANSACTION', 'BEGIN', 'COMMIT')
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
          described_class.manageable_community_ids(user.person, ids)
        end
        n
      end

      small_batch = count_queries.call([community_a.id])
      large_batch = count_queries.call(candidate_ids + Array.new(20) { create(:better_together_community).id })

      # A per-record policy(candidate).update? loop issues a distinct
      # record_permission_granted? query per candidate for a record-scoped-permission
      # user like this one — 23 vs. 1 candidates would cost ~22 more queries that way.
      # The batched query's cost is dominated by a fixed permission-cache warm-up, not
      # candidate count, so the delta between 1 and 23 candidates should be tiny.
      expect(large_batch - small_batch).to be < 5
    end
  end
end
