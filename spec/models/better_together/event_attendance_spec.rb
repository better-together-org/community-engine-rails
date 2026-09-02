# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventAttendance do
  let(:person) { create(:better_together_person) }
  let(:event) { create(:better_together_event, name: 'Test', starts_at: Time.zone.now) }
  let(:attendance) { described_class.create!(event:, person:, status: 'interested') }

  it 'validates inclusion of status' do
    attendance = described_class.new(status: 'invalid_status')

    expect(attendance).not_to be_valid
  end

  it 'includes expected error for invalid status' do
    attendance = described_class.new(status: 'invalid_status')
    attendance.valid?

    expect(attendance.errors[:status]).to be_present
  end

  it 'enforces uniqueness per event/person' do
    duplicate = described_class.new(event: attendance.event, person: attendance.person)

    expect(duplicate).not_to be_valid
  end

  it 'includes uniqueness error for duplicate attendance' do
    duplicate = described_class.new(event: attendance.event, person: attendance.person)
    duplicate.valid?

    expect(duplicate.errors[:event_id]).to include('has already been taken')
  end

  # Acceptance criteria for per-occurrence attendance (Part 0/1 of
  # docs/implementation/current_plans/event_occurrences_acceptance_criteria.md).
  describe 'per-occurrence attendance (AC-1.1, AC-1.2, AC-1.3)' do
    let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }
    let(:occurrence_date) { recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date }
    let(:occurrence) { BetterTogether::EventOccurrence.create!(event:, occurrence_date:) }
    let(:other_occurrence_date) { recurrence.occurrences_between(2.weeks.from_now, 2.years.from_now).first.to_date }
    let(:other_occurrence) { BetterTogether::EventOccurrence.create!(event:, occurrence_date: other_occurrence_date) }

    it 'allows one series-wide attendance and one independent per-session attendance for the same person' do
      series_wide = described_class.create!(event:, person:, status: 'interested')
      per_session = described_class.new(event:, event_occurrence: occurrence, person:, status: 'going')

      expect(per_session).to be_valid
      expect(series_wide).to be_persisted
    end

    it 'does not let marking one session "going" change another session\'s attendance status' do
      described_class.create!(event:, event_occurrence: occurrence, person:, status: 'going')
      other_session_attendance = described_class.find_by(event:, event_occurrence: other_occurrence, person:)

      expect(other_session_attendance).to be_nil
    end

    it 'cancelling a per-session RSVP removes only that session\'s attendance record' do
      this_session = described_class.create!(event:, event_occurrence: occurrence, person:, status: 'going')
      series_wide = described_class.create!(event:, person:, status: 'interested')

      this_session.destroy!

      expect(described_class.exists?(series_wide.id)).to be true
    end
  end
end
