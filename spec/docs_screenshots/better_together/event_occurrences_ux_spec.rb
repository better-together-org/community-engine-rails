# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/event_occurrences_ux_spec.rb
#
# Documents PR #1717: per-occurrence attendance/comments/overrides, plus
# recurrence-aware events index and calendar occurrence expansion. See
# docs/implementation/current_plans/event_occurrences_acceptance_criteria.md.
RSpec.describe 'Documentation screenshots for per-occurrence event data', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', host_url: 'http://www.example.com')
    end
  end
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:creator) { create(:better_together_person, name: 'Harbour Events Team') }

  # ends_at must be overridden alongside starts_at — the factory's ends_at
  # default is independent of starts_at, which would give a weekly-recurring
  # event a multi-week duration_minutes and break simple_calendar's per-day
  # bucketing (see spec/features/events/event_occurrences_ux_spec.rb for the
  # full explanation of this gotcha). change(hour: 14) pins a safe mid-day
  # UTC start — 2.weeks.ago alone inherits whatever real-world hour the spec
  # happens to run at, and a start within ~2 hours of UTC midnight makes a
  # short event genuinely straddle two calendar dates (simple_calendar then
  # correctly, but confusingly for a screenshot, shows it on both day cells).
  let(:recurring_event) do
    create(:event, platform: host_platform, creator:, name: 'Weekly Harbourside Trivia Night',
                   starts_at: 2.weeks.ago.change(hour: 14, min: 0, sec: 0),
                   ends_at: 2.weeks.ago.change(hour: 16, min: 0, sec: 0))
  end
  let(:recurrence) { create(:recurrence, :weekly, schedulable: recurring_event) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures the events index card carrying a "Repeats" badge and the recurring filter control' do
    recurring_event
    recurrence
    create(:event, platform: host_platform, creator:, name: 'One-time Harbour Cleanup', starts_at: 4.days.from_now,
                   ends_at: 4.days.from_now + 3.hours)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1717_events_index_repeating_badge',
      # desktop only — the recurring_filter callout targets #events-recurring,
      # which sits inside the filter sidebar that's collapsed behind
      # #events-filter-toggle on mobile (see events_index_filter_spec.rb's
      # dedicated mobile capture for that collapsed-state pattern); the
      # callout processor needs it actually visible to draw its box.
      device: :desktop,
      metadata: docs_metadata(flow: 'events_index_recurring_badge'),
      callouts: [
        {
          id: 'recurring_filter',
          selector: '#events-recurring',
          title: 'Recurring / one-time filter',
          bullets: ['New tri-state filter: All / Recurring only / One-time only.']
        },
        {
          id: 'recurring_badge',
          selector: '.event-recurring-badge',
          title: '"Repeats" badge',
          bullets: [
            'Visible text label, never color alone — aria-label carries the full frequency summary.',
            'The displayed date is next_occurrence_at (override-aware), never the stale original starts_at.'
          ]
        }
      ],
      narrative: {
        title: 'Events Index — recurring event badge and filter',
        audience: %w[community_member event_organizer platform_manager developer],
        journey_step: 'As a community member browsing events, I can tell at a glance which events ' \
                      'repeat, and filter the list to just recurring (or just one-time) events.',
        callouts: [
          { id: 'recurring_filter', title: 'Recurring / one-time filter',
            description: 'EventsSearchFilter#filter_by_recurring — a plain AR left_joins(:recurrence), ' \
                         'no raw SQL.' },
          { id: 'recurring_badge', title: '"Repeats" badge',
            description: 'BadgesHelper#recurring_badge; tooltip/aria-label built from ' \
                         'RecurrenceHelper#format_recurrence_rule.' }
        ],
        accessibility_notes: 'Badge conveys meaning via text, not color; filter control has an ' \
                             'explicit <label for> association.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:)

      expect(page).to have_css('.event-recurring-badge', text: /Repeats/i, wait: 10)
      expect(page).to have_css('#events-recurring')
    end
  end

  it 'captures the event show page Sessions tab listing upcoming occurrences' do
    recurring_event
    recurrence

    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1717_event_sessions_tab',
      device: :both,
      metadata: docs_metadata(flow: 'event_show_sessions_tab'),
      callouts: [
        {
          id: 'sessions_tab',
          selector: '#sessions-tab',
          title: 'Sessions tab',
          bullets: ['Only shown for recurring events — links to the upcoming-occurrences list.']
        },
        {
          id: 'sessions_list',
          selector: '#event-upcoming-sessions',
          title: 'Upcoming sessions list',
          bullets: [
            'Computed on demand via Event#occurrences_between — no EventOccurrence row exists ' \
            'for any of these dates until someone actually RSVPs, comments, or an organizer ' \
            'overrides one.'
          ]
        }
      ],
      narrative: {
        title: 'Event show page — Sessions tab',
        audience: %w[event_attendee event_organizer developer],
        journey_step: 'As an attendee, I open a recurring event and see its next several sessions ' \
                      'listed by date, so I know which dates I could RSVP or comment on individually.',
        callouts: [
          { id: 'sessions_tab', title: 'Sessions tab',
            description: 'app/views/better_together/events/show.html.erb — gated on event.recurring?.' },
          { id: 'sessions_list', title: 'Upcoming sessions list',
            description: 'RecurrenceHelper#next_occurrences_list — the overwhelming majority of ' \
                         'occurrences are never touched, so this never creates a database row just ' \
                         'from being viewed.' }
        ],
        accessibility_notes: 'Tab uses standard Bootstrap nav/tab-pane ARIA roles ' \
                             '(role="tab"/"tabpanel", aria-controls, aria-selected).'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.event_path(recurring_event, locale:)
      expect(page).to have_css('#sessions-tab', wait: 10)
      find('#sessions-tab').click

      expect(page).to have_css('#sessions.show', wait: 10)
      expect(page).to have_css('#event-upcoming-sessions li', minimum: 1, wait: 5)
    end
  end

  it 'captures the calendar month grid showing the same recurring event on multiple day cells' do
    recurring_event
    recurrence
    calendar = create('better_together/calendar', privacy: 'public')
    calendar.calendar_entries.create!(event: recurring_event, starts_at: recurring_event.starts_at,
                                      ends_at: recurring_event.ends_at)

    # Strictly within the current calendar month (no padding) — simple_calendar's
    # month grid always fully contains the current month, but its exact
    # start-of-week padding on either side isn't guaranteed to reach a full
    # week, so dates outside the month itself aren't safe to assume visible.
    occurrence_dates = recurring_event.occurrences_between(
      Date.current.beginning_of_month, Date.current.end_of_month
    ).map(&:date).sort
    first_date = occurrence_dates.first
    second_date = occurrence_dates[1]

    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1717_calendar_recurring_multiple_dates',
      device: :both,
      metadata: docs_metadata(flow: 'calendar_recurring_expansion'),
      callouts: [
        {
          id: 'first_occurrence',
          selector: "#calendar-day-#{first_date.iso8601}-events",
          title: 'First occurrence day cell',
          bullets: ['CalendarOccurrenceExpander expands the recurrence rule into one Occurrence per date.']
        },
        {
          id: 'second_occurrence',
          selector: "#calendar-day-#{second_date.iso8601}-events",
          title: 'Same event, a different day cell',
          bullets: [
            'Before this PR, a recurring event only ever appeared on its original creation date, ' \
            'never on any later occurrence.'
          ]
        }
      ],
      narrative: {
        title: 'Calendar — a weekly event on every occurrence date',
        audience: %w[community_member event_organizer platform_manager developer],
        journey_step: 'As someone planning around a calendar, I see a weekly event show up every ' \
                      'week it actually happens, not just once.',
        callouts: [
          { id: 'first_occurrence', title: 'First occurrence day cell',
            description: 'app/services/better_together/calendar_occurrence_expander.rb, windowed ' \
                         '±6 weeks around the navigated start_date.' },
          { id: 'second_occurrence', title: 'Same event, a different day cell',
            description: 'Both cells link to the same canonical event show page — ' \
                         'better_together.event_path, with turbo_frame: "_top" so the click ' \
                         'actually navigates instead of silently no-oping inside the tab\'s frame.' }
        ],
        accessibility_notes: 'Each day-cell link uses the event name as its accessible text; no ' \
                             'information is conveyed by position or color alone.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.calendar_path(calendar, locale:)

      expect(page).to have_css("#calendar-day-#{first_date.iso8601}-events .calendar-event-link",
                               text: recurring_event.name, wait: 10)
    end
  end

  it 'captures a cancelled occurrence showing a clear "Cancelled" indicator on the calendar' do
    recurring_event
    recurrence
    calendar = create('better_together/calendar', privacy: 'public')
    calendar.calendar_entries.create!(event: recurring_event, starts_at: recurring_event.starts_at,
                                      ends_at: recurring_event.ends_at)

    occurrence_date = recurring_event.occurrences_between(Time.current, 1.year.from_now).first.date
    BetterTogether::EventOccurrence.create!(event: recurring_event, occurrence_date:, cancelled: true)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1717_calendar_cancelled_occurrence',
      device: :both,
      metadata: docs_metadata(flow: 'calendar_cancelled_occurrence'),
      callouts: [
        {
          id: 'cancelled_badge',
          selector: '.event-session-cancelled-badge',
          title: '"Cancelled" indicator',
          bullets: [
            'Shown directly on the day cell — a cancelled session never just silently disappears, ' \
            'which would look identical to "nothing was ever scheduled here."'
          ]
        }
      ],
      narrative: {
        title: 'Calendar — cancelled occurrence indicator',
        audience: %w[event_attendee event_organizer developer],
        journey_step: 'As an attendee checking the calendar, I can immediately tell a specific ' \
                      'session was cancelled rather than wondering if it was ever scheduled.',
        callouts: [
          { id: 'cancelled_badge', title: '"Cancelled" indicator',
            description: 'RecurringSchedulable#occurrences_between always includes cancelled dates ' \
                         '(never filters them out) precisely so display code like this can render ' \
                         'the badge instead of a silent gap.' }
        ],
        accessibility_notes: 'Text badge, not color-only; same pattern as the event show page\'s ' \
                             'own Sessions list.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.calendar_path(calendar, locale:)

      expect(page).to have_css("#calendar-day-#{occurrence_date.iso8601}-events .event-session-cancelled-badge",
                               wait: 10)
    end
  end

  private

  def docs_metadata(flow:)
    {
      locale:,
      role: 'platform_manager',
      feature_set: 'event_occurrences_ux',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
