# frozen_string_literal: true

require 'rails_helper'

# Acceptance criteria for the recurring badge (AC-3.8-3.10) and true
# calendar occurrence expansion (AC-4.1-4.5). See
# docs/implementation/current_plans/event_occurrences_acceptance_criteria.md.
# Parts 3 and 4 are implemented.
RSpec.describe 'Event occurrences UX', :accessibility, :js, retry: 0 do
  let(:locale) { I18n.default_locale }
  let(:organizer) { create(:better_together_user) }
  # privacy: 'public' on both — CalendarPolicy#show? requires privacy_public?
  # (or community membership), and PrivacyCeilingValidatable forbids a
  # calendar's privacy from exceeding its community's. Both factories
  # default to 'private', which would either deny the auto-logged-in
  # generic test user (redirecting to the platform home) or fail calendar
  # creation outright.
  let(:community) { create(:better_together_community, privacy: 'public') }
  let(:calendar) { create(:better_together_calendar, community:, privacy: 'public') }
  let(:event) do
    # ends_at must be overridden alongside starts_at — the factory's ends_at
    # default (1.week.from_now + 2.hours) is independent of starts_at, so
    # leaving it out here would give this event a multi-week duration_minutes.
    # simple_calendar's group_events_by_date spans an event across every day
    # from start to end date inclusive, so each weekly occurrence would then
    # stack onto every other occurrence's date within that span — the same
    # gotcha already documented in calendars_controller_spec.rb.
    create(:better_together_event, creator: organizer.person, name: 'Weekly Trivia Night',
                                   starts_at: 2.weeks.ago,
                                   ends_at: 2.weeks.ago + 2.hours)
  end
  let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }

  before do
    event.event_hosts.create!(host: organizer.person)
    recurrence
    calendar.calendar_entries.create!(event:, starts_at: event.starts_at, ends_at: event.ends_at)
  end

  describe 'recurring badge on the events index (AC-3.8, AC-3.9, AC-3.10)' do
    it 'shows a "Repeats" badge with visible text, not color alone, and an accessible explanation' do
      visit better_together.events_path(locale:)

      badge = find('.event-recurring-badge', text: /Repeats/i)
      expect(badge['aria-label']).to be_present
    end

    it 'passes WCAG 2.1 AA on the index card and recurring filter control' do
      visit better_together.events_path(locale:)

      expect(page).to be_axe_clean
        .within('#events')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'calendar grid shows every occurrence, not just the original date (AC-4.1, AC-4.2, AC-4.3)' do
    it 'shows the recurring event on multiple future date cells within the visible month' do
      visit better_together.calendar_path(calendar, locale:)

      occurrence_dates = recurrence.occurrences_between(Time.current, 3.weeks.from_now).map(&:to_date)
      occurrence_dates.each do |date|
        expect(page).to have_css("#calendar-day-#{date.iso8601}-events .calendar-event-link", text: event.name)
      end
      expect(occurrence_dates.size).to be > 1 # sanity: this genuinely tests multiple distinct dates
    end

    it 'shows the recurring event\'s occurrence when navigating to a future month (AC-4.2)' do
      future_month_start = 2.months.from_now.beginning_of_month.to_date
      visit better_together.calendar_path(calendar, locale:, start_date: future_month_start.iso8601)

      future_occurrence = recurrence.occurrences_between(future_month_start, future_month_start.end_of_month).first

      expect(page).to have_css("#calendar-day-#{future_occurrence.to_date.iso8601}-events", text: event.name)
    end

    it 'links a future occurrence\'s day-cell entry to the correct, single canonical event page (AC-4.3)' do
      visit better_together.calendar_path(calendar, locale:)
      future_date = recurrence.occurrences_between(1.week.from_now, 1.year.from_now).first.to_date

      within("#calendar-day-#{future_date.iso8601}-events") { click_link event.name }

      expect(page).to have_current_path(%r{/events/#{event.to_param}}, ignore_query: true)
    end
  end

  describe 'calendar reflects organizer overrides and cancellations (AC-4.4, AC-4.5)' do
    it 'shows an overridden occurrence on its (possibly moved) effective date, not the stale computed one' do
      occurrence_date = recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
      moved_date = occurrence.effective_starts_at + 1.day
      occurrence.update!(starts_at: moved_date)

      visit better_together.calendar_path(calendar, locale:)

      expect(page).to have_css("#calendar-day-#{moved_date.to_date.iso8601}-events", text: event.name)
    end

    it 'shows a clear "Cancelled" indicator on a cancelled occurrence\'s date, not a silent absence' do
      occurrence_date = recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date
      BetterTogether::EventOccurrence.create!(event:, occurrence_date:, cancelled: true)

      visit better_together.calendar_path(calendar, locale:)

      within("#calendar-day-#{occurrence_date.iso8601}-events") do
        expect(page).to have_content(/Cancelled/i)
      end
    end
  end
end
