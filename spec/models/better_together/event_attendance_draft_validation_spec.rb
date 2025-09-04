# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventAttendance, 'draft event validation' do
    let(:person) { create(:better_together_person) }
    let(:draft_event) { create(:event, :draft) }
    let(:scheduled_event) { create(:event, :upcoming) }

    describe 'validation for scheduled events' do
      it 'allows RSVP for scheduled events' do
        attendance = described_class.new(event: scheduled_event, person: person, status: 'interested')

        expect(attendance).to be_valid
      end

      it 'prevents RSVP for draft events' do # rubocop:todo RSpec/MultipleExpectations
        attendance = described_class.new(event: draft_event, person: person, status: 'interested')

        expect(attendance).not_to be_valid
        expect(attendance.errors[:event]).to include('must be scheduled to allow RSVPs')
      end
    end
  end
end
