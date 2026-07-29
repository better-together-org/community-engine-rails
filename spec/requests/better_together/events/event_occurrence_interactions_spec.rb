# frozen_string_literal: true

require 'rails_helper'

# RED-phase acceptance criteria for per-occurrence RSVP/override request flows
# (docs/implementation/current_plans/event_occurrences_acceptance_criteria.md,
# Phase 1 AC-1.4/AC-1.5 and Phase 2 AC-2.1/AC-2.4-2.6). None of these routes
# or controller actions exist yet — every example is expected to fail until
# the corresponding part of the plan lands.
RSpec.describe 'Per-occurrence event interactions' do
  let(:locale) { I18n.default_locale }
  let(:organizer) { create(:better_together_user, :confirmed) }
  let(:attendee) { create(:better_together_user, :confirmed) }
  let(:event) { create(:better_together_event, creator: organizer.person, name: 'Community Book Club') }
  let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }
  let(:occurrence_date) { recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date }
  let(:other_occurrence_date) { recurrence.occurrences_between(2.weeks.from_now, 2.years.from_now).first.to_date }

  before do
    event.event_hosts.create!(host: organizer.person)
    recurrence
  end

  describe 'attendee RSVPs to one specific session (AC-1.2, AC-1.4)' do
    before { login(attendee.email, 'SecureTest123!@#') }

    it 'confirms which session date the RSVP applies to, and does not affect other sessions' do
      pending 'AC-1.2/AC-1.4: per-occurrence RSVP endpoint not yet implemented'

      post "/events/#{event.to_param}/occurrences/#{occurrence_date.iso8601}/rsvp_going",
           params: { locale: }

      expect(response).to have_http_status(:success).or have_http_status(:redirect)
      expect_html_content(occurrence_date.to_s) # confirmation names the specific date, not just the series
      other_attendance = BetterTogether::EventAttendance.find_by(
        event:, person: attendee.person,
        event_occurrence: BetterTogether::EventOccurrence.find_by(event:, occurrence_date: other_occurrence_date)
      )
      expect(other_attendance).to be_nil
    end
  end

  describe 'attendee comments on one specific session (AC-1.5)' do
    before { login(attendee.email, 'SecureTest123!@#') }

    it 'attaches the comment to that session only, not the parent event or other sessions' do
      pending 'AC-1.5: per-occurrence comment endpoint not yet implemented'

      post "/events/#{event.to_param}/occurrences/#{occurrence_date.iso8601}/comments",
           params: { locale:, comment: { content: 'Looking forward to this one!' } }

      occurrence = BetterTogether::EventOccurrence.find_by(event:, occurrence_date:)
      expect(occurrence.comments.reload).not_to be_empty
      expect(event.comments).to be_empty if event.respond_to?(:comments)
    end
  end

  describe 'organizer overrides one session\'s time and location (AC-2.1)' do
    before { login(organizer.email, 'SecureTest123!@#') }

    it 'updates only that occurrence, leaving the recurrence rule and other sessions untouched' do
      pending 'AC-2.1: organizer per-occurrence override endpoint not yet implemented'

      new_time = recurrence.occurrences_between(Time.current, 1.year.from_now).first + 2.hours
      patch "/events/#{event.to_param}/occurrences/#{occurrence_date.iso8601}",
            params: { locale:, event_occurrence: { starts_at: new_time } }

      occurrence = BetterTogether::EventOccurrence.find_by(event:, occurrence_date:)
      expect(occurrence.effective_starts_at).to eq(new_time)
      expect(BetterTogether::EventOccurrence.find_by(event:, occurrence_date: other_occurrence_date)).to be_nil
    end
  end

  describe 'a non-host cannot override a session (AC-2.3)' do
    before { login(attendee.email, 'SecureTest123!@#') }

    it 'denies the override attempt' do
      pending 'AC-2.3: EventOccurrencePolicy denial not yet wired into the controller'

      patch "/events/#{event.to_param}/occurrences/#{occurrence_date.iso8601}",
            params: { locale:, event_occurrence: { cancelled: true } }

      expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
    end
  end

  describe 'cancelling a session preserves existing attendance/comments (AC-2.4)' do
    before { login(organizer.email, 'SecureTest123!@#') }

    it 'does not delete the occurrence row or its associations when cancelled' do
      pending 'AC-2.4: cancellation preserving history not yet implemented'

      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
      attendee_attendance = BetterTogether::EventAttendance.create!(
        event:, event_occurrence: occurrence, person: attendee.person, status: 'going'
      )

      patch "/events/#{event.to_param}/occurrences/#{occurrence_date.iso8601}",
            params: { locale:, event_occurrence: { cancelled: true } }

      expect(occurrence.reload).to be_cancelled
      expect(BetterTogether::EventAttendance.exists?(attendee_attendance.id)).to be true
    end
  end

  describe 'event show page reflects a cancelled/overridden session unambiguously (AC-2.5, AC-2.6)' do
    it 'shows a clear "Cancelled" indicator, not just an absent listing' do
      pending 'AC-2.6: cancelled-session display not yet implemented'

      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:, cancelled: true)
      get better_together.event_path(event, locale:)

      expect_html_content('Cancelled')
      expect(occurrence).to be_cancelled # sanity anchor for the AC once the view assertion above is real
    end
  end
end
