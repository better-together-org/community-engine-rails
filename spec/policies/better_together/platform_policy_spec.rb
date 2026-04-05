# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformPolicy do
  describe '#show?' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:community_platform) { create(:platform, privacy: 'community', community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

    it 'allows community members to view community-scoped platforms' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role
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
        role: community_member_role
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
  end
end
