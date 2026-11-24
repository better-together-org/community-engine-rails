# frozen_string_literal: true

require 'rails_helper'

# @hermetic
RSpec.describe 'Membership lifecycle' do # rubocop:disable RSpec/DescribeClass
  before { configure_host_platform }

  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:person) { create(:better_together_person) }
  let(:member_role) { BetterTogether::Role.find_by!(identifier: 'platform_member', platform:) }
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward', platform:) }
  let(:actor) { create(:better_together_person) }

  def membership(role: member_role, who: person, **attrs)
    platform.person_platform_memberships.create!(member: who, role:, status: 'active', **attrs)
  end

  describe '.active / current?' do
    it 'counts only memberships inside their dates' do
      current = membership
      future = membership(who: create(:better_together_person), starts_at: 1.day.from_now)
      lapsed = membership(who: create(:better_together_person), ends_at: 1.day.ago, starts_at: 2.days.ago)

      expect(BetterTogether::PersonPlatformMembership.active).to include(current)
      expect(BetterTogether::PersonPlatformMembership.active).not_to include(future, lapsed)
      expect([current.current?, future.current?, lapsed.current?]).to eq([true, false, false])
    end
  end

  describe '#end!' do
    it 'keeps the row as history, stamps the end and records who and why' do
      record = membership
      record.end!(reason: 'left the group', actor:)

      expect(record.reload).to have_attributes(status: 'ended', ended_reason: 'left the group')
      expect(record.ends_at).to be_within(5.seconds).of(Time.current)
      expect(BetterTogether::PersonPlatformMembership.active).not_to include(record)
      event = record.membership_events.find_by(event_type: 'ended')
      expect(event).to have_attributes(actor_id: actor.id, from_status: 'active', to_status: 'ended',
                                       reason: 'left the group')
    end

    it 'lets the same role be granted again after it ended' do
      membership.end!
      expect { membership }.not_to raise_error
    end

    it 'does not notify the member of a quiet end' do
      record = membership
      expect { record.end! }.not_to(change(Noticed::Event, :count))
    end
  end

  describe 'suspend! and reinstate!' do
    it 'toggles status, clears the end and logs both events' do
      record = membership
      record.suspend!(reason: 'under review', actor:)
      expect(record.reload).to be_suspended
      expect(BetterTogether::PersonPlatformMembership.active).not_to include(record)

      record.reinstate!(actor:)
      expect(record.reload).to be_active
      expect(record.membership_events.pluck(:event_type)).to include('suspended', 'reinstated')
    end
  end

  describe 'event trail' do
    it 'records creation, role change and removal' do
      record = membership
      record.update!(role: steward_role)
      record.destroy!

      events = BetterTogether::MembershipEvent.where(membership_id: record.id).order(:created_at)
      expect(events.pluck(:event_type)).to eq(%w[created role_changed removed])
    end

    it 'refuses to edit an event' do
      membership
      event = BetterTogether::MembershipEvent.last
      expect(event.update(reason: 'x')).to be(false)
    end
  end

  describe 'last steward guard' do
    it 'refuses to end or suspend the only steward' do
      BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward_role).delete_all
      sole = membership(role: steward_role)
      expect { sole.end! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(sole.reload).to be_active
      expect { sole.suspend! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'allows it when another current steward remains' do
      BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward_role).delete_all
      first = membership(role: steward_role)
      membership(role: steward_role, who: create(:better_together_person))
      expect { first.end! }.not_to raise_error
    end
  end

  it 'rejects an end before the start' do
    record = platform.person_platform_memberships.build(member: person, role: member_role, starts_at: 1.day.from_now,
                                                        ends_at: Time.current)
    expect(record).not_to be_valid
  end
end
