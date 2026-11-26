# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Permission wiring in policies', type: :policy do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:community) { create(:better_together_community) }

  before { configure_host_platform }

  def member_with(role_identifier, joinable)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonCommunityMembership.create!(
      joinable:, member: user.person, status: 'active',
      role: BetterTogether::Role.find_default(role_identifier, platform:)
    )
    user
  end

  describe 'CommunityPolicy#destroy?' do
    it 'allows a holder of delete_community (community organizer)' do
      organizer = member_with('community_organizer', community)
      expect(BetterTogether::CommunityPolicy.new(organizer, community).destroy?).to be true
    end

    it 'does not let settings or members permissions delete a community' do
      coordinator = member_with('community_coordinator', community)
      policy = BetterTogether::CommunityPolicy.new(coordinator, community)

      expect(policy.update?).to be true
      expect(policy.destroy?).to be false
    end

    it 'still lets a platform manager delete a community' do
      manager = create(:better_together_user, :confirmed, :platform_manager)
      expect(BetterTogether::CommunityPolicy.new(manager, community).destroy?).to be true
    end
  end

  describe 'EventPolicy with manage_community_events' do
    let(:event) do
      create(:better_together_event, creator: create(:better_together_person)).tap do |e|
        BetterTogether::EventHost.create!(event: e, host: community)
        e.event_hosts.reset
      end
    end

    it 'lets a holder update and destroy events hosted by the community' do
      coordinator = member_with('community_facilitator', community)
      policy = BetterTogether::EventPolicy.new(coordinator, event)

      expect([policy.update?, policy.destroy?]).to all(be(true))
    end

    it 'does not let an unrelated person change the event' do
      outsider = create(:better_together_user, :confirmed)
      policy = BetterTogether::EventPolicy.new(outsider, event)

      expect([policy.update?, policy.destroy?]).to all(be(false))
    end
  end
end
