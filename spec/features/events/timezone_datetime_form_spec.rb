# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event form timezone-aware datetime handling', :as_platform_manager, :js, retry: 0 do
  let(:locale) { I18n.default_locale }

  # Helper to submit event form via JavaScript (more reliable than button click in tests)
  def submit_event_form
    page.execute_script("document.querySelector('form[id^=form_event]').requestSubmit()")
    sleep 1 # Allow submission to process
  end

  before do
    # Ensure clean session state to prevent parallel test pollution
    visit better_together.destroy_user_session_path(locale: locale)
    capybara_login_as_platform_manager
  end

  scenario 'creating an event with datetime values respects event timezone' do
    visit better_together.new_event_path(locale: locale)

    # Wait for form to be ready
    expect(page).to have_css('#event-form-tabs', wait: 10)
    expect(page).to have_field("event[name_#{locale}]", wait: 10)

    # Fill in basic event details
    fill_in "event[name_#{locale}]", with: 'Timezone Test Event'

    # Navigate to time and place tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show', wait: 10)

    # Wait for timezone select (SlimSelect initialization)
    expect(page).to have_css('select[name="event[timezone]"]', visible: :all, wait: 10)
    expect(page).to have_css('.ss-main', wait: 5)

    # Select Eastern timezone
    find('.ss-main', match: :first).click
    within('.ss-content') do
      find('.ss-option', text: /Eastern Time/, match: :first).click
    end

    # Fill in datetime fields - wait for them to be present first
    expect(page).to have_field('event_starts_at', wait: 5)
    expect(page).to have_field('event_ends_at', wait: 5)

    # Use JavaScript to set datetime values (more reliable than fill_in for datetime-local)
    page.execute_script("document.getElementById('event_starts_at').value = '2026-03-15T14:00'")
    page.execute_script("document.getElementById('event_ends_at').value = '2026-03-15T16:00'")

    # Submit the form
    submit_event_form

    # Wait for redirect
    expect(page).to have_current_path(%r{/(events|en/events)}, wait: 10)

    # Find the created event
    event = BetterTogether::Event.order(:created_at).last
    expect(event).to be_present
    expect(event.name).to eq('Timezone Test Event')
    expect(event.timezone).to eq('America/New_York')

    # March 15, 2026 is after DST starts (March 8), so EDT is active (UTC-4)
    # 2:00 PM EDT = 6:00 PM UTC (14:00 + 4 hours for EDT offset)
    expect(event.starts_at.utc.hour).to eq(18)
    expect(event.starts_at.utc.day).to eq(15)
    expect(event.starts_at.utc.month).to eq(3)

    # 4:00 PM EDT = 8:00 PM UTC
    expect(event.ends_at.utc.hour).to eq(20)

    # Verify local times match what was entered
    expect(event.local_starts_at.hour).to eq(14)
    expect(event.local_ends_at.hour).to eq(16)
  end

  scenario 'editing an event preserves datetime values in event timezone' do
    # Create an event in Los Angeles timezone
    # Using May 15, 2026 which has PDT active (UTC-7)
    event = create(:better_together_event,
                   timezone: 'America/Los_Angeles',
                   starts_at: Time.utc(2026, 5, 15, 19, 0),  # 12:00 PM PDT (UTC-7)
                   ends_at: Time.utc(2026, 5, 15, 21, 0),    # 2:00 PM PDT (UTC-7)
                   creator: BetterTogether::User.find_by(email: 'manager@example.test').person)

    visit better_together.edit_event_path(event, locale: locale)

    # Wait for form to load
    expect(page).to have_css('#event-form-tabs', wait: 10)

    # Navigate to time and place tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show', wait: 10)

    # Verify the datetime fields show the local time (12:00 PM and 2:00 PM in LA time)
    starts_field = find_field('event_starts_at')
    ends_field = find_field('event_ends_at')

    expect(starts_field.value).to eq('2026-05-15T12:00')
    expect(ends_field.value).to eq('2026-05-15T14:00')

    # Change the times to 3:00 PM and 5:00 PM (still in LA time)
    page.execute_script("document.getElementById('event_starts_at').value = '2026-05-15T15:00'")
    page.execute_script("document.getElementById('event_ends_at').value = '2026-05-15T17:00'")

    # Submit the form
    submit_event_form

    # Wait for processing
    sleep 2

    # Reload the event
    event.reload

    # Timezone should be unchanged
    expect(event.timezone).to eq('America/Los_Angeles')

    # May 15, 2026 has PDT active (UTC-7)
    # 3:00 PM PDT = 10:00 PM UTC (15 + 7)
    expect(event.starts_at.utc.hour).to eq(22)

    # 5:00 PM PDT = 12:00 AM UTC next day (17 + 7)
    expect(event.ends_at.utc.hour).to eq(0)
    expect(event.ends_at.utc.day).to eq(16)

    # Verify local times match what was entered
    expect(event.local_starts_at.hour).to eq(15)
    expect(event.local_ends_at.hour).to eq(17)

    # Re-visit the form to verify values are displayed correctly
    visit better_together.edit_event_path(event, locale: locale)

    # Wait for form to load
    expect(page).to have_css('#event-form-tabs', wait: 10)

    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show', wait: 10)

    starts_field = find_field('event_starts_at')
    ends_field = find_field('event_ends_at')

    # Should show the updated times in LA timezone
    expect(starts_field.value).to eq('2026-05-15T15:00')
    expect(ends_field.value).to eq('2026-05-15T17:00')
  end

  scenario 'changing event timezone updates how datetime values are interpreted' do
    # Create an event in Central timezone
    event = create(:better_together_event,
                   timezone: 'America/Chicago',
                   starts_at: Time.utc(2026, 6, 10, 19, 0),  # 2:00 PM CDT (UTC-5)
                   ends_at: Time.utc(2026, 6, 10, 21, 0),    # 4:00 PM CDT
                   creator: BetterTogether::User.find_by(email: 'manager@example.test').person)

    visit better_together.edit_event_path(event, locale: locale)

    # Wait for form to load
    expect(page).to have_css('#event-form-tabs', wait: 10)

    # Navigate to time and place tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show', wait: 10)

    # Verify original times display correctly in Central time
    expect(find_field('event_starts_at').value).to eq('2026-06-10T14:00')
    expect(find_field('event_ends_at').value).to eq('2026-06-10T16:00')

    # Change timezone to Mountain time
    expect(page).to have_css('.ss-main', wait: 5)
    find('.ss-main', match: :first).click

    # Search for Mountain timezone option
    within('.ss-content') do
      # Try different patterns that might match Mountain time
      # The display might be "Mountain Time (US & Canada)" or include "Denver"
      option = all('.ss-option').find { |opt| opt.text.match?(/Mountain|Denver/i) }
      if option
        option.click
      else
        # Fallback: scroll through options to find it
        find('.ss-option', text: /Mountain/, match: :first).click
      end
    end

    # Enter new times (should be interpreted as Mountain time now)
    page.execute_script("document.getElementById('event_starts_at').value = '2026-06-10T15:00'")
    page.execute_script("document.getElementById('event_ends_at').value = '2026-06-10T17:00'")

    # Submit
    submit_event_form
    sleep 2

    event.reload

    # Verify timezone changed
    expect(event.timezone).to eq('America/Denver')

    # June 10, 2026 has MDT active (UTC-6)
    # 3:00 PM MDT = 9:00 PM UTC (15 + 6)
    expect(event.starts_at.utc.hour).to eq(21)

    # 5:00 PM MDT = 11:00 PM UTC (17 + 6)
    expect(event.ends_at.utc.hour).to eq(23)

    # Verify local times in new timezone
    expect(event.local_starts_at.hour).to eq(15)
    expect(event.local_ends_at.hour).to eq(17)
  end
end
