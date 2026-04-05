# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformPolicy do
  describe 'Scope' do
    let!(:public_platform) { create(:platform, :public) }
    let!(:community_platform) { create(:platform, privacy: 'community') }

    it 'includes community-scoped platforms for signed-in users' do
      user = create(:better_together_user)

      resolved = described_class::Scope.new(user, BetterTogether::Platform).resolve

      expect(resolved).to include(public_platform, community_platform)
    end

    it 'excludes community-scoped platforms for guests' do
      resolved = described_class::Scope.new(nil, BetterTogether::Platform).resolve

      expect(resolved).to include(public_platform)
      expect(resolved).not_to include(community_platform)
    end
  end
end
