# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventPolicy do
  describe '#show?' do
    let(:community_event) { create(:event, privacy: 'community') }

    it 'allows signed-in users to view community-scoped events with start times' do
      user = create(:better_together_user)

      expect(described_class.new(user, community_event).show?).to be true
    end

    it 'denies guests from viewing community-scoped events' do
      expect(described_class.new(nil, community_event).show?).to be false
    end
  end

  describe 'Scope' do
    let!(:public_event) { create(:event, privacy: 'public') }
    let!(:community_event) { create(:event, privacy: 'community') }

    it 'includes community-scoped events for signed-in users' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::Event).resolve

      expect(resolved).to include(public_event, community_event)
    end

    it 'excludes community-scoped events for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Event).resolve

      expect(resolved).to include(public_event)
      expect(resolved).not_to include(community_event)
    end
  end
end
