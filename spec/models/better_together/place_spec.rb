# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Place do
  subject(:place) { described_class.new(space: space) }

  let(:space) { create(:geography_space) }
  let(:community) { create(:better_together_community) }

  describe 'associations' do
    it 'responds to community (optional)' do
      expect(place).to respond_to(:community)
    end

    it 'responds to space' do
      expect(place).to respond_to(:space)
    end
  end

  describe 'creation' do
    it 'can be persisted with a space and community' do
      p = create(:better_together_place, space: space, community: community)
      expect(p).to be_persisted
      expect(p.space).to eq(space)
      expect(p.community).to eq(community)
    end
  end

  describe 'community assignment (CommunityAssignable)' do
    let(:local_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
    let(:remote_platform) { create(:better_together_platform, :external) }

    it "assigns the platform's own community when community is nil, not the host community" do
      federated_place = build(:better_together_place, space: space, platform: remote_platform, community: nil)

      federated_place.valid?

      expect(federated_place.community).to eq(remote_platform.community)
      expect(federated_place.community).not_to eq(local_platform.community)
    end

    it 'falls back to the host community when the platform has no community of its own' do
      allow(remote_platform).to receive(:community).and_return(nil)
      place_without_platform_community = build(
        :better_together_place, space: space, platform: remote_platform, community: nil
      )

      place_without_platform_community.valid?

      expect(place_without_platform_community.community).to eq(BetterTogether::Community.host_community)
    end

    it 'leaves an explicitly-assigned community untouched' do
      place_with_explicit_community = build(
        :better_together_place, space: space, platform: remote_platform, community: community
      )

      place_with_explicit_community.valid?

      expect(place_with_explicit_community.community).to eq(community)
    end

    it 'can be persisted without ever setting community_id explicitly' do
      federated_place = create(:better_together_place, space: space, platform: remote_platform, community: nil)

      expect(federated_place).to be_persisted
      expect(federated_place.community_id).to eq(remote_platform.community.id)
    end
  end
end
