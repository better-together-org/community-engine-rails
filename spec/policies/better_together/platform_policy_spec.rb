# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformPolicy do
  let(:platform_steward_role) { BetterTogether::Role.find_by(identifier: 'platform_steward') }
  let(:host_platform) { BetterTogether::Platform.find_by!(host: true) }

  def grant_platform_steward!(person, platform)
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform,
      member: person,
      role: platform_steward_role,
      status: 'active'
    )
  end

  describe '#create?' do
    let(:tenant_platform) { create(:platform) }
    let(:internal_draft) { build(:platform, external: false) }
    let(:external_draft) { build(:platform, :external) }

    it 'denies guests' do
      expect(described_class.new(nil, internal_draft).create?).to be false
    end

    it 'allows a host platform steward to create an internally-hosted tenant platform' do
      host_steward = create(:better_together_user, :platform_steward)

      expect(described_class.new(host_steward, internal_draft).create?).to be true
    end

    it 'allows a host platform steward to register an external federation peer' do
      host_steward = create(:better_together_user, :platform_steward)

      expect(described_class.new(host_steward, external_draft).create?).to be true
    end

    it 'allows a network_admin (host-scoped) to register an external federation peer' do
      network_admin = create(:better_together_user, :network_admin)

      expect(described_class.new(network_admin, external_draft).create?).to be true
    end

    it 'denies a network_admin from creating an internally-hosted tenant platform' do
      network_admin = create(:better_together_user, :network_admin)

      expect(described_class.new(network_admin, internal_draft).create?).to be false
    end

    it 'denies a steward of a tenant (non-host) platform from creating another tenant platform' do
      tenant_user = create(:better_together_user)
      grant_platform_steward!(tenant_user.person, tenant_platform)

      expect(described_class.new(tenant_user, internal_draft).create?).to be false
    end

    it 'denies a steward of a tenant (non-host) platform from registering an external peer' do
      tenant_user = create(:better_together_user)
      grant_platform_steward!(tenant_user.person, tenant_platform)

      expect(described_class.new(tenant_user, external_draft).create?).to be false
    end
  end

  describe '#update?' do
    let(:platform_a) { create(:platform) }
    let(:platform_b) { create(:platform) }

    it 'allows a steward of platform A to update platform A' do
      user = create(:better_together_user)
      grant_platform_steward!(user.person, platform_a)

      expect(described_class.new(user, platform_a).update?).to be true
    end

    it 'denies a steward of platform A from updating platform B' do
      user = create(:better_together_user)
      grant_platform_steward!(user.person, platform_a)

      expect(described_class.new(user, platform_b).update?).to be false
    end
  end

  describe '#destroy?' do
    let(:platform_a) { create(:platform) }
    let(:platform_b) { create(:platform) }

    it 'allows a steward of platform A to destroy platform A' do
      user = create(:better_together_user)
      grant_platform_steward!(user.person, platform_a)

      expect(described_class.new(user, platform_a).destroy?).to be true
    end

    it 'denies a steward of platform A from destroying platform B' do
      user = create(:better_together_user)
      grant_platform_steward!(user.person, platform_a)

      expect(described_class.new(user, platform_b).destroy?).to be false
    end
  end

  describe '#show?' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:community_platform) { create(:platform, privacy: 'community', community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

    it 'allows community members to view community-scoped platforms' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role,
        status: 'active'
      )

      expect(described_class.new(user, community_platform).show?).to be true
    end

    it 'denies signed-in non-members from viewing community-scoped platforms' do
      user = create(:better_together_user)

      expect(described_class.new(user, community_platform).show?).to be false
    end
  end

  describe 'Scope' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let!(:public_platform) { create(:platform, :public) }
    let!(:community_platform) { create(:platform, privacy: 'community', community: scoped_community) }

    it 'includes community-scoped platforms for members' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role,
        status: 'active'
      )

      resolved = described_class::Scope.new(user, BetterTogether::Platform).resolve

      expect(resolved).to include(public_platform, community_platform)
    end

    it 'excludes community-scoped platforms for signed-in non-members' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::Platform).resolve

      expect(resolved).to include(public_platform)
      expect(resolved).not_to include(community_platform)
    end

    it 'excludes community-scoped platforms for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Platform).resolve

      expect(resolved).to include(public_platform)
      expect(resolved).not_to include(community_platform)
    end

    it "includes a tenant steward's own private platform but not another tenant's private platform" do
      platform_a = create(:platform, privacy: 'private')
      platform_b = create(:platform, privacy: 'private')
      user = create(:better_together_user)
      steward_role = BetterTogether::Role.find_by(identifier: 'platform_steward')
      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform_a, member: user.person, role: steward_role, status: 'active'
      )

      resolved = described_class::Scope.new(user, BetterTogether::Platform).resolve

      expect(resolved).to include(platform_a)
      expect(resolved).not_to include(platform_b)
    end
  end
end
