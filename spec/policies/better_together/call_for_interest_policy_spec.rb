# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CallForInterestPolicy do
  describe '#show?' do
    let(:community_call) { create(:call_for_interest, privacy: 'community') }

    it 'allows signed-in users to view community-scoped calls for interest' do
      user = create(:better_together_user)

      expect(described_class.new(user, community_call).show?).to be true
    end

    it 'denies guests from viewing community-scoped calls for interest' do
      expect(described_class.new(nil, community_call).show?).to be false
    end
  end

  describe 'Scope' do
    let!(:public_call) { create(:call_for_interest, privacy: 'public') }
    let!(:community_call) { create(:call_for_interest, privacy: 'community') }

    it 'includes community-scoped calls for signed-in users' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::CallForInterest).resolve

      expect(resolved).to include(public_call, community_call)
    end

    it 'excludes community-scoped calls for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::CallForInterest).resolve

      expect(resolved).to include(public_call)
      expect(resolved).not_to include(community_call)
    end
  end
end
