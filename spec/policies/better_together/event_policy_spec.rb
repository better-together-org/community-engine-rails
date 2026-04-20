# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventPolicy do
  describe '#show?' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let(:community_event) { create(:event, privacy: 'community', platform: scoped_platform) }

    it 'allows community members to view community-scoped events with start times' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role
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

  describe 'Scope' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let!(:public_event) { create(:event, privacy: 'public') }
    let!(:community_event) { create(:event, privacy: 'community', platform: scoped_platform) }

    it 'includes community-scoped events for members' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role
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
end
