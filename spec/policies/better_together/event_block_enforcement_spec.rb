# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event policies with person blocks', type: :policy do # rubocop:disable RSpec/DescribeClass
  let(:creator) { create(:better_together_person) }
  let(:viewer) { create(:better_together_person) }
  let(:creator_user) { create(:better_together_user, :confirmed, person: creator) }
  let(:viewer_user) { create(:better_together_user, :confirmed, person: viewer) }
  let!(:event) { create(:better_together_event, creator:, privacy: 'public') }

  before { configure_host_platform }

  describe BetterTogether::EventPolicy do
    it 'shows a public event when there is no block' do
      expect(described_class.new(viewer_user, event).show?).to be true
    end

    it 'hides the event from someone the creator blocked', :aggregate_failures do
      create(:person_block, blocker: creator, blocked: viewer)

      expect(described_class.new(viewer_user, event).show?).to be false
      expect(described_class::Scope.new(viewer_user, BetterTogether::Event).resolve).not_to include(event)
    end

    it 'hides the event from someone who blocked the creator', :aggregate_failures do
      create(:person_block, blocker: viewer, blocked: creator)

      expect(described_class.new(viewer_user, event).show?).to be false
      expect(described_class::Scope.new(viewer_user, BetterTogether::Event).resolve).not_to include(event)
    end

    it 'still lists the event for unrelated viewers' do
      create(:person_block, blocker: creator, blocked: create(:better_together_person))

      expect(described_class::Scope.new(viewer_user, BetterTogether::Event).resolve).to include(event)
    end
  end

  describe BetterTogether::EventAttendancePolicy do
    let(:attendance) { BetterTogether::EventAttendance.new(event:, person: viewer) }

    it 'allows an RSVP when there is no block' do
      expect(described_class.new(viewer_user, attendance).create?).to be true
    end

    it 'denies RSVPs across a block in either direction', :aggregate_failures do
      block = create(:person_block, blocker: creator, blocked: viewer)
      expect(described_class.new(viewer_user, attendance).create?).to be false

      block.destroy!
      create(:person_block, blocker: viewer, blocked: creator)
      expect(described_class.new(viewer_user, attendance).create?).to be false
    end
  end

  describe BetterTogether::EventInvitationPolicy do
    let(:invitee) { create(:better_together_person) }
    let(:invitation) { BetterTogether::EventInvitation.new(invitable: event, inviter: creator, invitee:) }

    it 'allows the creator to invite someone without a block' do
      expect(described_class.new(creator_user, invitation).create?).to be true
    end

    it 'denies inviting someone the inviter blocked' do
      create(:person_block, blocker: creator, blocked: invitee)

      expect(described_class.new(creator_user, invitation).create?).to be false
    end

    it 'denies inviting someone who blocked the inviter' do
      create(:person_block, blocker: invitee, blocked: creator)

      expect(described_class.new(creator_user, invitation).create?).to be false
    end
  end
end
