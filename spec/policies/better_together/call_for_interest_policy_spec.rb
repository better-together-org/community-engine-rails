# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CallForInterestPolicy do
  describe '#show?' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:scoped_event) { create(:event, platform: scoped_platform) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let(:community_call) { create(:call_for_interest, :with_event, privacy: 'community', interestable: scoped_event) }

    it 'allows community members to view community-scoped calls for interest' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role
      )

      expect(described_class.new(user, community_call).show?).to be true
    end

    it 'denies signed-in non-members from viewing community-scoped calls for interest' do
      user = create(:better_together_user)

      expect(described_class.new(user, community_call).show?).to be false
    end

    it 'denies guests from viewing community-scoped calls for interest' do
      expect(described_class.new(nil, community_call).show?).to be false
    end
  end

  describe 'Scope' do
    let(:scoped_community) { create(:better_together_community, privacy: 'public') }
    let(:scoped_platform) { create(:better_together_platform, community: scoped_community) }
    let(:scoped_event) { create(:event, platform: scoped_platform) }
    let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
    let!(:public_call) { create(:call_for_interest, privacy: 'public') }
    let!(:community_call) { create(:call_for_interest, :with_event, privacy: 'community', interestable: scoped_event) }

    it 'includes community-scoped calls for members' do
      user = create(:better_together_user)
      BetterTogether::PersonCommunityMembership.create!(
        joinable: scoped_community,
        member: user.person,
        role: community_member_role
      )

      resolved = described_class::Scope.new(user, BetterTogether::CallForInterest).resolve

      expect(resolved).to include(public_call, community_call)
    end

    it 'excludes community-scoped calls for signed-in non-members' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::CallForInterest).resolve

      expect(resolved).to include(public_call)
      expect(resolved).not_to include(community_call)
    end

    it 'excludes community-scoped calls for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::CallForInterest).resolve

      expect(resolved).to include(public_call)
      expect(resolved).not_to include(community_call)
    end
  end
end
