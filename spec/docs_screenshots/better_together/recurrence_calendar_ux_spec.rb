# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c "RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/recurrence_calendar_ux_spec.rb"
#
# Documents the PR fixing/improving the calendar grid and recurrence form:
# see docs/assessments and the PR description for the full bug list.
RSpec.describe 'Documentation screenshots for the calendar grid and recurrence form', # rubocop:disable RSpec/SpecFilePathSuffix
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

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    grant_content_publishing_agreement(manager.person)
  end

  after do
    Current.platform = nil
  end

  def visit_new_event_recurrence_tab
    capybara_login_as_platform_manager
    visit better_together.new_event_path(locale:)
    expect(page).to have_css('#event-form-tabs', wait: 10)
    fill_in "event[name_#{locale}]", with: 'Weekly Team Sync'
    find('#event-recurrence-tab').click
    expect(page).to have_css('#event-recurrence.show', wait: 10)
  end

  it 'captures the calendar month grid actually showing an event in its day cell' do
    calendar = create('better_together/calendar', privacy: 'public')
    upcoming_event = create(:better_together_event, name: 'Monthly Board Meeting',
                                                    starts_at: 2.days.from_now, identifier: SecureRandom.uuid)
    past_event = create(:better_together_event, name: 'Past Volunteer Day',
                                                starts_at: 3.days.ago, ends_at: 3.days.ago + 1.hour,
                                                identifier: SecureRandom.uuid)
    BetterTogether::CalendarEntry.create!(calendar:, event: upcoming_event, starts_at: upcoming_event.starts_at)
    BetterTogether::CalendarEntry.create!(calendar:, event: past_event, starts_at: past_event.starts_at)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_calendar_grid_with_events',
      device: :both,
      metadata: screenshot_metadata(flow: 'calendar_show', role: 'platform_manager'),
      callouts: [
        {
          id: 'day_cell_event',
          selector: '.calendar-event-link',
          title: 'Event now visible in its day cell',
          bullets: [
            'The month/week/day grid previously rendered zero events, ever.',
            'Each day cell now links directly to the event on the date it actually occurs.'
          ]
        },
        {
          id: 'upcoming_list',
          selector: '#calendar-upcoming-events-list',
          title: 'Upcoming events list',
          bullets: [
            'Computed by the controller since before this PR, but never rendered anywhere.',
            'Now surfaced as a plain list alongside the grid.'
          ]
        }
      ],
      narrative: {
        title: 'Calendar — month grid with real events',
        audience: %w[community_organizer platform_manager developer],
        journey_step: 'As a community member, I open a calendar to see what is scheduled this month.',
        callouts: [
          { id: 'day_cell_event', title: 'Event now visible in its day cell',
            description: 'simple_calendar yields (date, day_events) per cell; the view previously ' \
                         'only declared |date| and never rendered day_events at all.' },
          { id: 'upcoming_list', title: 'Upcoming events list',
            description: '@upcoming_events/@past_events were computed by the controller but never ' \
                         'referenced anywhere in the view before this fix.' }
        ],
        accessibility_notes: 'Day-cell event links and the upcoming/past lists use plain anchor tags ' \
                             'with the event name as their accessible text.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.calendar_path(calendar, locale:)

      expect(page).to have_css('.calendar-event-link', text: 'Monthly Board Meeting', wait: 10)
    end
  end

  it 'captures the recurrence tab defaulting to a pre-checked weekday with shortcut buttons' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_recurrence_weekly_defaults',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_recurrence_weekly', role: 'platform_manager'),
      callouts: [
        {
          id: 'weekday_shortcuts',
          selector: '#recurrence-weekday-shortcuts',
          title: 'Weekday shortcut buttons',
          bullets: ['One click for the common "weekdays only", "every day", or "clear" patterns.']
        },
        {
          id: 'default_weekday',
          selector: '.weekday-checkboxes',
          title: 'Default weekday pre-checked',
          bullets: [
            "The event's own start-date weekday is pre-checked the first time Weekly is selected.",
            'Applied only once — never fights a user who deliberately clears every box.'
          ]
        }
      ],
      narrative: {
        title: 'Recurrence form — weekly frequency defaults',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, I pick Weekly and immediately see a sensible default day ' \
                      'plus one-click shortcuts, instead of an all-unchecked set of boxes.',
        callouts: [
          { id: 'weekday_shortcuts', title: 'Weekday shortcut buttons',
            description: 'Calls RecurrenceController#selectWeekdaysMonToFri/#selectAllWeekdays/#clearWeekdays.' },
          { id: 'default_weekday', title: 'Default weekday pre-checked',
            description: 'Previously every checkbox rendered unchecked on edit too, due to a Symbol/' \
                         'Integer mismatch in Recurrence#weekdays — fixed earlier in this PR.' }
        ],
        accessibility_notes: 'Weekday checkbox ids no longer contain literal [ ] characters from ' \
                             'form.object_name, which previously broke label association entirely.'
      }
    ) do
      visit_new_event_recurrence_tab
      select 'Weekly', from: 'event[recurrence_attributes][frequency]'

      expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', minimum: 1, wait: 5)
    end
  end

  it 'captures the monthly "same weekday position" option and the never-ends warning' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_recurrence_monthly_option_and_warning',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_recurrence_monthly', role: 'platform_manager'),
      callouts: [
        {
          id: 'month_option',
          selector: '#recurrence_month_option_day_of_week',
          title: '"Same weekday position" option',
          bullets: [
            'New in this PR: choose "same day of month" (default) vs "same weekday position" ' \
            '(e.g. the 3rd Tuesday).',
            'The ordinal/weekday are derived from the event\'s own start date — no extra pickers.'
          ]
        },
        {
          id: 'never_warning',
          selector: '#recurrence-never-ends-warning',
          title: '"Never ends" warning',
          bullets: ['"Never" is the default end type — this warns before it is left in place by accident.']
        }
      ],
      narrative: {
        title: 'Recurrence form — monthly option and never-ends warning',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer scheduling a monthly meeting on "the 3rd Tuesday", I can now ' \
                      'express that directly instead of only "the 15th of every month".',
        callouts: [
          { id: 'month_option', title: '"Same weekday position" option',
            description: 'RecurrenceScheduleBuilder#apply_month_option builds an IceCube day_of_week ' \
                         'rule, correctly falling back to "last" when the month has no 5th occurrence.' },
          { id: 'never_warning', title: '"Never ends" warning',
            description: 'Toggled by RecurrenceController#updateVisibility based on the end_type select.' }
        ],
        accessibility_notes: 'Both radio options have explicit <label for> associations; the warning ' \
                             'uses role="alert".'
      }
    ) do
      visit_new_event_recurrence_tab
      select 'Monthly', from: 'event[recurrence_attributes][frequency]'
      choose 'recurrence_month_option_day_of_week'

      expect(page).to have_css('#recurrence-never-ends-warning', wait: 5)
    end
  end

  it 'captures the live preview showing a plain-English summary and real occurrence dates' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_recurrence_live_preview',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_recurrence_preview', role: 'platform_manager'),
      callouts: [
        {
          id: 'preview_summary',
          selector: '#recurrence-preview-summary',
          title: 'Plain-English rule summary',
          bullets: ['Confirms the whole configuration at a glance instead of parsing 5 separate fields.']
        },
        {
          id: 'preview_occurrences',
          selector: '#recurrence-preview-occurrences',
          title: 'Real upcoming occurrence dates',
          bullets: [
            'The preview endpoint existed before this PR but was never actually wired to any field ' \
            '— every interaction silently did nothing.'
          ]
        }
      ],
      narrative: {
        title: 'Recurrence form — live preview',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, I see the exact dates this rule produces before saving, ' \
                      'instead of finding out after the fact.',
        callouts: [
          { id: 'preview_summary', title: 'Plain-English rule summary',
            description: 'RecurrenceHelper#recurrence_attrs_summary, rendered server-side in the ' \
                         'same partial as the occurrence list.' },
          { id: 'preview_occurrences', title: 'Real upcoming occurrence dates',
            description: 'Every field now has a data-action wired to a debounced fetch; previously ' \
                         'only frequency/end_type called updateVisibility, never updatePreview.' }
        ],
        accessibility_notes: 'The preview container has role="status" aria-live="polite" so updates ' \
                             'are announced to screen readers.'
      }
    ) do
      visit_new_event_recurrence_tab
      select 'Weekly', from: 'event[recurrence_attributes][frequency]'
      select 'After occurrences', from: 'event[recurrence_attributes][end_type]'
      fill_in 'event[recurrence_attributes][count]', with: '3'

      expect(page).to have_css('#recurrence-preview-occurrences li', minimum: 1, wait: 5)
    end
  end

  it 'captures the repeatable exception-date rows with two dates added' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_recurrence_exception_dates',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_recurrence_exception_dates', role: 'platform_manager'),
      callouts: [
        {
          id: 'exception_rows',
          selector: '#exception-dates-container',
          title: 'Repeatable native date-picker rows',
          bullets: [
            'Replaces a single comma-separated textarea that silently dropped unparseable entries.',
            'Add/remove mirrors the existing event_hosts_controller.js template-clone pattern.'
          ]
        }
      ],
      narrative: {
        title: 'Recurrence form — exception dates',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, I exclude specific dates (e.g. a holiday) from a recurring ' \
                      'series using a real date picker instead of typing "YYYY-MM-DD" by hand.',
        callouts: [
          { id: 'exception_rows', title: 'Repeatable native date-picker rows',
            description: 'An unparseable entry now blocks the save with a real validation error ' \
                         'instead of being silently dropped.' }
        ],
        accessibility_notes: 'Each date input has an aria-label; the remove button has an ' \
                             'aria-label naming the action, not just an "x" glyph.'
      }
    ) do
      visit_new_event_recurrence_tab
      2.times { click_button 'Add exception date' }

      expect(page).to have_css('#exception-dates-container .exception-date-row', count: 2, wait: 5)
    end
  end

  it 'captures the general form-errors block surfacing a validation error' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'pr1692_event_form_general_errors',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_form_errors', role: 'platform_manager'),
      callouts: [
        {
          id: 'form_errors',
          selector: '#form_errors',
          title: 'General form errors block',
          bullets: [
            'Rendered inline inside turbo_frame_tag \'form_errors\' so the plain format.html ' \
            'fallback (Turbo disabled / no JS) is never silently blank. When Turbo Drive is ' \
            'active, the controller\'s own turbo_stream.update overwrites this frame with the ' \
            'shared errors partial — same frame, one final element, never both at once.'
          ]
        }
      ],
      narrative: {
        title: 'Event form — general validation errors are now visible',
        audience: %w[event_organizer platform_manager developer],
        journey_step: 'As an organizer, if I select "On date" but leave the date blank, I now see ' \
                      'exactly why my save failed instead of a silent no-op.',
        callouts: [
          { id: 'form_errors', title: 'General form errors block',
            description: 'Reads event.errors excluding the three fields (privacy/status/location) ' \
                         'that already had their own inline treatment; rendered inside the shared ' \
                         'turbo_frame_tag \'form_errors\' rather than a separate sibling element, so ' \
                         'the controller\'s turbo_stream.update replaces it in place instead of ' \
                         'stacking alongside it.' }
        ],
        accessibility_notes: 'The errors block is a standard Bootstrap alert-danger with a heading; ' \
                             'no color-only signal.'
      }
    ) do
      visit_new_event_recurrence_tab
      select 'Weekly', from: 'event[recurrence_attributes][frequency]'
      select 'On date', from: 'event[recurrence_attributes][end_type]'
      # Deliberately leave ends_on blank, then submit
      page.execute_script("document.querySelector('form[id^=form_event]').requestSubmit()")

      expect(page).to have_css('#form_errors .alert-danger', wait: 10)
      expect(page).to have_css('#event-form-errors', count: 0)
    end
  end

  private

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'recurrence_calendar_ux',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
