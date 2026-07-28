# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event recurrence form interactivity', :accessibility, :as_platform_manager, :js, retry: 0 do
  let(:locale) { I18n.default_locale }
  let(:manager_person) { BetterTogether::User.find_by(email: 'manager@example.test').person }
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end

  before do
    visit better_together.destroy_user_session_path(locale: locale)
    capybara_login_as_platform_manager
    BetterTogether::AgreementParticipant.find_or_create_by!(
      participant: manager_person,
      agreement: content_publishing_agreement
    ) do |participant|
      participant.person = manager_person
      participant.accepted_at = Time.current
    end
  end

  def visit_recurrence_tab
    visit better_together.new_event_path(locale: locale)

    expect(page).to have_css('#event-form-tabs', wait: 10)
    fill_in "event[name_#{locale}]", with: 'Recurrence UX Test Event'

    find('#event-recurrence-tab').click
    expect(page).to have_css('#event-recurrence.show', wait: 10)
  end

  scenario 'weekday checkboxes only show for weekly frequency' do
    visit_recurrence_tab

    expect(page).not_to have_css('[data-better-together--recurrence-target="weekdaysField"][style*="display: block"]')

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    expect(page).to have_css('[data-better-together--recurrence-target="weekdaysField"][style*="display: block"]', wait: 5)

    select 'Daily', from: 'event[recurrence_attributes][frequency]'
    # visible: :all — the element being asserted on is deliberately hidden
    # (display: none), so Capybara's default visible-only search would never
    # find it.
    expect(page).to have_css(
      '[data-better-together--recurrence-target="weekdaysField"][style*="display: none"]', visible: :all, wait: 5
    )
  end

  scenario 'end-type fields toggle correctly and the never-ends warning appears for the default selection' do
    visit_recurrence_tab

    select 'Daily', from: 'event[recurrence_attributes][frequency]'

    expect(page).to have_css('#recurrence-never-ends-warning', wait: 5)

    select 'On date', from: 'event[recurrence_attributes][end_type]'
    expect(page).not_to have_css('#recurrence-never-ends-warning')
    expect(page).to have_css('[data-better-together--recurrence-target="untilDateField"][style*="display: block"]', wait: 5)

    select 'After occurrences', from: 'event[recurrence_attributes][end_type]'
    expect(page).to have_css('[data-better-together--recurrence-target="countField"][style*="display: block"]', wait: 5)
    expect(page).not_to have_css('[data-better-together--recurrence-target="untilDateField"][style*="display: block"]')
  end

  scenario 'selecting a frequency shows the series-wide edit note and unit label' do
    visit_recurrence_tab

    # #recurrence-series-note is the inner <p> — the wrapping div carrying
    # the seriesNote target (and the style JS actually toggles) is what to
    # assert on.
    series_note_wrapper = '[data-better-together--recurrence-target="seriesNote"]'
    expect(page).not_to have_css("#{series_note_wrapper}[style*=\"display: block\"]")

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'

    expect(page).to have_css("#{series_note_wrapper}[style*=\"display: block\"]", wait: 5)
    expect(find('#interval-unit-label')).to have_text('week', wait: 5)
  end

  scenario 'the live preview updates with real occurrence dates once a complete recurrence is selected' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    select 'After occurrences', from: 'event[recurrence_attributes][end_type]'
    fill_in 'event[recurrence_attributes][count]', with: '3'

    expect(page).to have_css('#recurrence-preview-occurrences li', minimum: 1, wait: 5)
  end

  scenario 'the preview reports an error instead of a false-empty state for an incomplete end condition' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    select 'On date', from: 'event[recurrence_attributes][end_type]'
    # Deliberately leave the paired ends_on date blank

    expect(page).to have_css('#recurrence-preview-error', wait: 5)
  end

  scenario 'pre-checks the event start-date weekday the first time weekly is selected' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'

    # No start date has been entered in this flow, so the view falls back to
    # today's weekday — matches the same fallback the app itself uses.
    expected_index = Time.zone.now.wday
    expect(page).to have_css(
      "input[type=\"checkbox\"][value=\"#{expected_index}\"]:checked", visible: :all, wait: 5
    )
  end

  scenario 'does not fight the user who deliberately clears every weekday afterwards' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', minimum: 1, wait: 5)

    click_button 'Clear'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', count: 0, wait: 5)

    # Switching away and back to weekly must not silently re-apply the default
    select 'Daily', from: 'event[recurrence_attributes][frequency]'
    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', count: 0, wait: 5)
  end

  scenario 'weekday shortcut buttons set the expected checkboxes' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'

    click_button 'Select all'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', count: 7, wait: 5)

    click_button 'Clear'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', count: 0, wait: 5)

    click_button 'Weekdays (Mon–Fri)'
    expect(page).to have_css('.weekday-checkboxes input[type="checkbox"]:checked', count: 5, wait: 5)
    checked_values = page.all('.weekday-checkboxes input[type="checkbox"]:checked', wait: 5).map(&:value)
    expect(checked_values.sort).to eq(%w[1 2 3 4 5])
  end

  scenario 'the preview includes a plain-English summary of the whole rule' do
    visit_recurrence_tab

    select 'Weekly', from: 'event[recurrence_attributes][frequency]'
    select 'After occurrences', from: 'event[recurrence_attributes][end_type]'
    fill_in 'event[recurrence_attributes][count]', with: '3'

    expect(page).to have_css('#recurrence-preview-summary', wait: 5)
    summary_text = find('#recurrence-preview-summary').text
    expect(summary_text).to include('Every')
    expect(summary_text).to include('occurrences')
  end

  scenario 'passes WCAG 2.1 AA accessibility checks with the recurrence tab open' do
    visit_recurrence_tab
    select 'Weekly', from: 'event[recurrence_attributes][frequency]'

    expect(page).to be_axe_clean
      .within('#event-recurrence')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
