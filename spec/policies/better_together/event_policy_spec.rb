# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventPolicy do
  def steward_of(platform)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform, member: user.person,
      role: BetterTogether::Role.find_by(identifier: 'platform_steward'), status: 'active'
    )
    user
  end

  describe '#show?' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:host_community) { host_platform.community }
    let(:community_event) { create(:event, privacy: 'community') }

    it 'allows community members to view community-scoped events with start times' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community,
        member: user.person,
        role: community_member_role,
        status: 'active'
      )

      expect(described_class.new(user, community_event).show?).to be true
    end

    it 'denies signed-in non-members from viewing community-scoped events' do
      user = create(:better_together_user)

      expect(described_class.new(user, community_event).show?).to be false
    end

    it 'denies guests from viewing community-scoped events' do
      expect(described_class.new(nil, community_event).show?).to be false
    end
  end

  describe '#create?' do
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:host_community) { host_platform.community }
    let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
    let(:member_user) { create(:better_together_user, :confirmed) }
    let(:non_member_user) { create(:better_together_user, :confirmed) }
    let(:event_hosted_by_community) do
      event = BetterTogether::Event.new
      event.event_hosts.build(host: host_community)
      event
    end

    it 'allows platform managers, no agreement or hosting relationship required' do
      expect(described_class.new(platform_manager_user, event_hosted_by_community).create?).to be true
    end

    it 'allows a manage_community_events permission holder without any agreement' do
      role = create(:better_together_role, :community_role)
      permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_community_events')
      role.assign_resource_permissions([permission.identifier])
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community, member: member_user.person, role: role, status: 'active'
      )

      expect(described_class.new(member_user, event_hosted_by_community).create?).to be true
    end

    it 'allows an active community member hosting via their community, once the publishing agreement is accepted' do
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community, member: member_user.person, role: community_member_role, status: 'active'
      )
      grant_content_publishing_agreement(member_user.person)

      expect(described_class.new(member_user, event_hosted_by_community).create?).to be true
    end

    it 'denies an active community member who has not accepted the publishing agreement — regression for the ' \
       'self-hosted-event agreement gap' do
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community, member: member_user.person, role: community_member_role, status: 'active'
      )

      expect(described_class.new(member_user, event_hosted_by_community).create?).to be false
    end

    it 'denies a non-member with no hosting relationship, even with the agreement accepted' do
      grant_content_publishing_agreement(non_member_user.person)

      expect(described_class.new(non_member_user, event_hosted_by_community).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, event_hosted_by_community).create?).to be false
    end
  end

  describe '#recurrence_preview?' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:host_community) { host_platform.community }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

    it 'allows a user eligible to create/edit events' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community,
        member: user.person,
        role: community_member_role,
        status: 'active'
      )

      expect(described_class.new(user, BetterTogether::Event).recurrence_preview?).to be true
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::Event).recurrence_preview?).to be false
    end
  end

  describe 'Scope' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
    let(:host_community) { host_platform.community }
    let!(:public_event) { create(:event, privacy: 'public') }
    let!(:community_event) { create(:event, privacy: 'community') }

    it 'includes community-scoped events for members' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: host_community,
        member: user.person,
        role: community_member_role,
        status: 'active'
      )

      resolved = described_class::Scope.new(user, BetterTogether::Event).resolve

      expect(resolved).to include(public_event, community_event)
    end

    it 'excludes community-scoped events for signed-in non-members' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::Event).resolve

      expect(resolved).to include(public_event)
      expect(resolved).not_to include(community_event)
    end

    it 'excludes community-scoped events for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Event).resolve

      expect(resolved).to include(public_event)
      expect(resolved).not_to include(community_event)
    end
  end

  describe 'cross-tenant isolation' do
    let(:platform_a) { create(:better_together_platform, :public) }
    let(:platform_b) { create(:better_together_platform, :public) }
    let(:platform_a_event) { create(:better_together_event, platform: platform_a) }
    let(:platform_b_event) { create(:better_together_event, platform: platform_b) }

    it "denies a steward of platform A from updating platform B's event" do
      steward_a = steward_of(platform_a)
      expect(described_class.new(steward_a, platform_b_event).update?).to be false
    end

    it "allows a steward of platform A to update platform A's own event" do
      steward_a = steward_of(platform_a)
      expect(described_class.new(steward_a, platform_a_event).update?).to be true
    end
  end
end
