# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::MembershipRequestPolicy, type: :policy do
  let(:community) { create(:better_together_community, allow_membership_requests: community_allows_requests) }
  let(:membership_request) { build(:better_together_joatu_membership_request, target: community) }
  let(:user) { nil }
  let(:community_allows_requests) { false }
  let(:platform_allows_requests) { false }

  before do
    create(:better_together_platform, community:, allow_membership_requests: platform_allows_requests)
  end

  context 'when neither the platform nor the community allows membership requests' do
    it 'forbids public creation' do
      expect(described_class.new(user, membership_request).create?).to be(false)
    end
  end

  context 'when the platform allows membership requests' do
    let(:platform_allows_requests) { true }

    it 'allows public creation' do
      expect(described_class.new(user, membership_request).create?).to be(true)
    end
  end

  context 'when the community allows membership requests' do
    let(:community_allows_requests) { true }

    it 'allows public creation' do
      expect(described_class.new(user, membership_request).create?).to be(true)
    end
  end
end
