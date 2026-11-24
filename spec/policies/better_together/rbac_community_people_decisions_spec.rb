# frozen_string_literal: true

require 'rails_helper'

# Approved access decisions CD-1 to CD-5, PD-1, PD-2 and PD-5 (see config/access_contracts).
RSpec.describe 'RBAC community and people decisions', type: :policy do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:steward) do
    create(:better_together_user, :confirmed).tap do |user|
      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform, member: user.person, status: 'active',
        role: BetterTogether::Role.find_default('platform_steward', platform:)
      )
    end
  end
  let(:private_community) { create(:better_together_community, privacy: 'private') }
  let(:community_only) { create(:better_together_community, privacy: 'community') }
  let(:public_community) { create(:better_together_community, privacy: 'public') }

  before { configure_host_platform }

  def member_with(role_identifier, joinable)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonCommunityMembership.create!(
      joinable:, member: user.person, status: 'active',
      role: BetterTogether::Role.find_default(role_identifier, platform:)
    )
    user
  end

  describe 'CD-1 platform roles do not read non-public communities' do
    it 'denies show, download and view_members on private and community-only communities', :aggregate_failures do
      [manager, steward].product([private_community, community_only]).each do |user, community|
        policy = BetterTogether::CommunityPolicy.new(user, community)
        expect([policy.show?, policy.download?, policy.view_members?]).to all(be(false))
      end
    end

    it 'keeps the public community readable but never its member list', :aggregate_failures do
      policy = BetterTogether::CommunityPolicy.new(manager, public_community)
      expect(policy.show?).to be true
      expect(policy.view_members?).to be false
    end

    it 'drops non-public communities from the index scope but keeps public ones', :aggregate_failures do
      private_community && community_only && public_community
      resolved = BetterTogether::CommunityPolicy::Scope.new(manager, BetterTogether::Community).resolve
      expect(resolved).to include(public_community)
      expect(resolved).not_to include(private_community, community_only)
    end

    it 'still shows a private community the manager belongs to' do
      organizer_manager = manager
      BetterTogether::PersonCommunityMembership.create!(
        joinable: private_community, member: organizer_manager.person, status: 'active',
        role: BetterTogether::Role.find_default('community_member', platform:)
      )
      expect(BetterTogether::CommunityPolicy.new(organizer_manager, private_community).show?).to be true
    end
  end

  describe 'CD-2 managers keep moderation and deletion, lose operation of non-public communities' do
    it 'keeps suspend, quarantine, hide, destroy and view_quota_usage on a private community', :aggregate_failures do
      policy = BetterTogether::CommunityPolicy.new(manager, private_community)
      expect([policy.suspend?, policy.quarantine?, policy.hide?, policy.destroy?, policy.view_quota_usage?]).to all(be(true))
    end

    it 'denies update, manage_roles, manage_integrations and create_events on private and community-only', :aggregate_failures do
      [private_community, community_only].each do |community|
        policy = BetterTogether::CommunityPolicy.new(manager, community)
        expect([policy.update?, policy.manage_roles?, policy.manage_integrations?, policy.create_events?]).to all(be(false))
      end
    end

    it 'still lets managers operate a public community', :aggregate_failures do
      policy = BetterTogether::CommunityPolicy.new(manager, public_community)
      expect([policy.update?, policy.manage_roles?, policy.manage_integrations?, policy.create_events?]).to all(be(true))
    end

    it 'denies moderation to ordinary members and organizers', :aggregate_failures do
      organizer = member_with('community_organizer', private_community)
      policy = BetterTogether::CommunityPolicy.new(organizer, private_community)
      expect([policy.suspend?, policy.quarantine?, policy.hide?]).to all(be(false))
      expect(policy.update?).to be true
    end
  end

  describe 'CD-3 and CD-4 invitations' do
    let(:inviter) { create(:better_together_user, :confirmed) }
    let!(:invitation) do
      create(:better_together_community_invitation, invitable: private_community, inviter: inviter.person, status: 'pending')
    end

    let(:listed_for) do
      ->(user) { BetterTogether::CommunityInvitationPolicy::Scope.new(user, BetterTogether::CommunityInvitation).resolve }
    end

    it 'hides invitations from a plain member even when another member can invite' do
      member_with('community_contributor', private_community)
      member = member_with('community_member', private_community)
      expect(listed_for.call(member)).not_to include(invitation)
    end

    it 'shows invitations to people who can invite or manage members' do
      organizer = member_with('community_organizer', private_community)
      contributor = member_with('community_contributor', private_community)
      expect([listed_for.call(organizer), listed_for.call(contributor)]).to all(include(invitation))
    end

    it 'lets an inviter see, resend and withdraw their own pending invitation', :aggregate_failures do
      policy = BetterTogether::CommunityInvitationPolicy.new(inviter, invitation)
      expect(listed_for.call(inviter)).to include(invitation)
      expect([policy.resend?, policy.destroy?]).to all(be(true))
    end

    it 'does not keep an inviter\'s rights once the invitation is accepted', :aggregate_failures do
      invitation.update_columns(status: 'accepted')
      policy = BetterTogether::CommunityInvitationPolicy.new(inviter, invitation)
      expect(listed_for.call(inviter)).not_to include(invitation)
      expect([policy.resend?, policy.destroy?]).to all(be(false))
    end

    it 'gives another person no rights over someone else\'s invitation', :aggregate_failures do
      other = create(:better_together_user, :confirmed)
      policy = BetterTogether::CommunityInvitationPolicy.new(other, invitation)
      expect([policy.resend?, policy.destroy?]).to all(be(false))
    end
  end

  describe 'CD-5 leaving a community' do
    it 'lets a member remove their own membership' do
      member = member_with('community_member', private_community)
      membership = member.person.person_community_memberships.find_by!(joinable: private_community)
      policy = BetterTogether::PersonCommunityMembershipPolicy.new(member, membership)
      expect([policy.destroy?, policy.destroy_denial_reason]).to eq([true, nil])
    end

    it 'refuses the only organizer with a clear reason' do
      organizer = member_with('community_organizer', private_community)
      membership = organizer.person.person_community_memberships.find_by!(joinable: private_community)
      policy = BetterTogether::PersonCommunityMembershipPolicy.new(organizer, membership)
      expect([policy.destroy?, policy.destroy_denial_reason]).to eq([false, :last_organizer])
    end

    it 'lets an organizer leave once another organizer exists' do
      organizer = member_with('community_organizer', private_community)
      member_with('community_organizer', private_community)
      membership = organizer.person.person_community_memberships.find_by!(joinable: private_community)
      expect(BetterTogether::PersonCommunityMembershipPolicy.new(organizer, membership).destroy?).to be true
    end

    it 'does not let one member remove another' do
      member = member_with('community_member', private_community)
      other = member_with('community_member', private_community)
      membership = other.person.person_community_memberships.find_by!(joinable: private_community)
      expect(BetterTogether::PersonCommunityMembershipPolicy.new(member, membership).destroy?).to be false
    end
  end

  describe 'PD-5 a blocker reads their own block' do
    let(:blocker) { create(:better_together_user, :confirmed) }
    let(:blocked) { create(:better_together_user, :confirmed) }
    let(:block) { BetterTogether::PersonBlock.create!(blocker: blocker.person, blocked: blocked.person, platform:) }

    it 'allows the blocker and nobody else', :aggregate_failures do
      expect(BetterTogether::PersonBlockPolicy.new(blocker, block).show?).to be true
      expect(BetterTogether::PersonBlockPolicy.new(blocked, block).show?).to be false
      expect(BetterTogether::PersonBlockPolicy.new(manager, block).show?).to be false
      expect(BetterTogether::PersonBlockPolicy.new(nil, block).show?).to be false
    end
  end

  describe 'PD-2 creating people' do
    it 'needs the opt-in create_person permission, not manager status', :aggregate_failures do
      expect(BetterTogether::PersonPolicy.new(manager, BetterTogether::Person).create?).to be false
      expect(BetterTogether::PersonPolicy.new(steward, BetterTogether::Person).create?).to be false
    end
  end

  describe 'PD-1 profile editing, claimed and unclaimed people' do
    let(:claimed_person) { create(:better_together_user, :confirmed).person }
    let(:unclaimed_person) { create(:better_together_person) }

    it 'defines claimed from a confirmed linked user', :aggregate_failures do
      unconfirmed = create(:better_together_user).person
      expect(claimed_person).to be_claimed
      expect(unclaimed_person).not_to be_claimed
      expect(unconfirmed).not_to be_claimed
    end

    it 'denies managers and stewards editing a claimed profile', :aggregate_failures do
      [manager, steward].each do |user|
        policy = BetterTogether::PersonPolicy.new(user, claimed_person)
        expect([policy.update?, policy.edit?]).to all(be(false))
      end
    end

    it 'lets managers and stewards edit an unclaimed profile', :aggregate_failures do
      [manager, steward].each do |user|
        expect(BetterTogether::PersonPolicy.new(user, unclaimed_person).update?).to be true
      end
    end

    it 'ends the exemption the moment a confirmed user claims the profile' do
      expect(BetterTogether::PersonPolicy.new(manager, unclaimed_person).update?).to be true
      user = create(:better_together_user, :confirmed)
      BetterTogether::Identification.where(agent: user).update_all(identity_id: unclaimed_person.id)
      expect(BetterTogether::PersonPolicy.new(manager, unclaimed_person.reload).update?).to be false
    end

    it 'keeps the person editing themself' do
      user = create(:better_together_user, :confirmed)
      expect(BetterTogether::PersonPolicy.new(user, user.person).update?).to be true
    end

    it 'keeps suspend and restore for managers, separate from profile editing', :aggregate_failures do
      policy = BetterTogether::PersonPolicy.new(manager, claimed_person)
      expect([policy.suspend?, policy.restore?]).to all(be(true))
      expect(policy.update?).to be false
      own = BetterTogether::PersonPolicy.new(manager, manager.person)
      expect(own.suspend?).to be false
      ordinary = BetterTogether::PersonPolicy.new(create(:better_together_user, :confirmed), claimed_person)
      expect([ordinary.suspend?, ordinary.restore?]).to all(be(false))
    end

    context 'with the opt-in manage_unclaimed_profiles permission' do
      let(:organizer) { member_with('community_organizer', private_community) }

      before do
        BetterTogether::AccessControlBuilder.seed_data
        BetterTogether::PersonCommunityMembership.create!(
          joinable: private_community, member: unclaimed_person, status: 'active',
          role: BetterTogether::Role.find_default('community_member', platform:)
        )
      end

      it 'is held by no default role' do
        grants = BetterTogether::Role.where(platform:).joins(:resource_permissions)
                                     .where(better_together_resource_permissions: { identifier: 'manage_unclaimed_profiles' })
        expect(grants).to be_empty
      end

      it 'denies an organizer without the grant' do
        expect(BetterTogether::PersonPolicy.new(organizer, unclaimed_person).update?).to be false
      end

      it 'lets an organizer with the grant edit an unclaimed person of their community, not a claimed one', :aggregate_failures do
        role = BetterTogether::Role.find_default('community_organizer', platform:)
        role.assign_resource_permissions(%w[manage_unclaimed_profiles])
        organizer.person.expire_permission_cache!

        expect(BetterTogether::PersonPolicy.new(organizer, unclaimed_person).update?).to be true
        expect(BetterTogether::PersonPolicy.new(organizer, claimed_person).update?).to be false
      end

      it 'does not extend to people outside the organizer\'s community with the grant' do
        BetterTogether::Role.find_default('community_organizer', platform:).assign_resource_permissions(%w[manage_unclaimed_profiles])
        organizer.person.expire_permission_cache!
        stranger = create(:better_together_person)

        expect(BetterTogether::PersonPolicy.new(organizer, stranger).update?).to be false
      end
    end
  end
end
