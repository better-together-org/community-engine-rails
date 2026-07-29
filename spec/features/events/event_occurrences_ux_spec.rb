# frozen_string_literal: true

require 'rails_helper'

# RED-phase acceptance criteria for the recurring badge (AC-3.8-3.10) and true
# calendar occurrence expansion (AC-4.1-4.5). See
# docs/implementation/current_plans/event_occurrences_acceptance_criteria.md.
# `recurring_badge`, the calendar's occurrence expansion, and the override/
# cancelled display do not exist yet — every example is expected to fail
# until Parts 3 and 4 land.
RSpec.describe 'Event occurrences UX', :accessibility, :js, retry: 0 do
  let(:locale) { I18n.default_locale }
  let(:organizer) { create(:better_together_user) }
  let(:community) { create(:better_together_community) }
  let(:calendar) { create(:better_together_calendar, community:) }
  let(:event) do
    create(:better_together_event, creator: organizer.person, name: 'Weekly Trivia Night', starts_at: 2.weeks.ago)
  end
  let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }

  before do
    event.event_hosts.create!(host: organizer.person)
    recurrence
    calendar.calendar_entries.create!(event:, starts_at: event.starts_at, ends_at: event.ends_at)
  end

  describe 'recurring badge on the events index (AC-3.8, AC-3.9, AC-3.10)' do
    it 'shows a "Repeats" badge with visible text, not color alone, and an accessible explanation' do
      pending 'AC-3.8/AC-3.9: recurring_badge helper not yet implemented'

      visit better_together.events_path(locale:)

      badge = find('.event-recurring-badge', text: /Repeats/i)
      expect(badge['aria-label']).to be_present
    end

    it 'passes WCAG 2.1 AA on the index card and recurring filter control' do
      pending 'AC-3.10: recurring filter control not yet implemented'

      visit better_together.events_path(locale:)

      expect(page).to be_axe_clean
        .within('#events')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'calendar grid shows every occurrence, not just the original date (AC-4.1, AC-4.2, AC-4.3)' do
    it 'shows the recurring event on multiple future date cells within the visible month' do
      pending 'AC-4.1: CalendarOccurrenceExpander not yet implemented'

      visit better_together.calendar_path(calendar, locale:)

      occurrence_dates = recurrence.occurrences_between(Time.current, 3.weeks.from_now).map(&:to_date)
      occurrence_dates.each do |date|
        expect(page).to have_css("#calendar-day-#{date.iso8601}-events .calendar-event-link", text: event.name)
      end
      expect(occurrence_dates.size).to be > 1 # sanity: this genuinely tests multiple distinct dates
    end

    it 'shows the recurring event\'s occurrence when navigating to a future month (AC-4.2)' do
      pending 'AC-4.2: windowed expansion around params[:start_date] not yet implemented'

      future_month_start = 2.months.from_now.beginning_of_month.to_date
      visit better_together.calendar_path(calendar, locale:, start_date: future_month_start.iso8601)

      future_occurrence = recurrence.occurrences_between(future_month_start, future_month_start.end_of_month).first

      expect(page).to have_css("#calendar-day-#{future_occurrence.to_date.iso8601}-events", text: event.name)
    end

    it 'links a future occurrence\'s day-cell entry to the correct, single canonical event page (AC-4.3)' do
      pending 'AC-4.3: Occurrence PORO delegation through dom_id/event_path not yet verified'

      visit better_together.calendar_path(calendar, locale:)
      future_date = recurrence.occurrences_between(1.week.from_now, 1.year.from_now).first.to_date

      within("#calendar-day-#{future_date.iso8601}-events") { click_link event.name }

      expect(page).to have_current_path(%r{/events/#{event.to_param}}, ignore_query: true)
    end
  end

  describe 'calendar reflects organizer overrides and cancellations (AC-4.4, AC-4.5)' do
    it 'shows an overridden occurrence on its (possibly moved) effective date, not the stale computed one' do
      pending 'AC-4.4: override-aware calendar expansion not yet implemented'

      occurrence_date = recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
      moved_date = occurrence.effective_starts_at + 1.day
      occurrence.update!(starts_at: moved_date)

      visit better_together.calendar_path(calendar, locale:)

      expect(page).to have_css("#calendar-day-#{moved_date.to_date.iso8601}-events", text: event.name)
    end

    it 'shows a clear "Cancelled" indicator on a cancelled occurrence\'s date, not a silent absence' do
      pending 'AC-4.5: cancelled indicator on calendar not yet implemented'

      occurrence_date = recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date
      BetterTogether::EventOccurrence.create!(event:, occurrence_date:, cancelled: true)

      visit better_together.calendar_path(calendar, locale:)

      within("#calendar-day-#{occurrence_date.iso8601}-events") do
        expect(page).to have_content(/Cancelled/i)
      end
    end
  end
end
