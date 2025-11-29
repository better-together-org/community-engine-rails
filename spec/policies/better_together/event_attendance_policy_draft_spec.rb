# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventAttendancePolicy, 'draft event restrictions' do
    let(:event_creator) { create(:better_together_person) }
    let(:user) { create(:better_together_user, person: event_creator) }
    let(:draft_event) { create(:event, :draft) }
    let(:scheduled_event) { create(:event, :upcoming) }

    describe '#create?' do
      it 'allows RSVP for scheduled events' do
        attendance = EventAttendance.new(event: scheduled_event, person: event_creator)
        policy = described_class.new(user, attendance)

        expect(policy.create?).to be true
      end

      it 'prevents RSVP for draft events' do
        attendance = EventAttendance.new(event: draft_event, person: event_creator)
        policy = described_class.new(user, attendance)

        expect(policy.create?).to be false
      end
    end

    describe '#update?' do
      it 'allows updates for scheduled events' do
        attendance = EventAttendance.create!(event: scheduled_event, person: event_creator, status: 'interested')
        policy = described_class.new(user, attendance)

        expect(policy.update?).to be true
      end

      it 'prevents updates for draft events' do
        # Create attendance with validation bypass for test setup
        attendance = EventAttendance.new(event: draft_event, person: event_creator, status: 'interested')
        attendance.save(validate: false)
        policy = described_class.new(user, attendance)

        expect(policy.update?).to be false
      end
    end
  end
end
