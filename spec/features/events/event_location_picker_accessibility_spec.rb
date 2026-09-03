# frozen_string_literal: true

require 'rails_helper'

# WCAG 2.1 AA coverage for the event form's mixed-search location picker and its
# inline "create a new address" panel. Mirrors
# timezone_selector_accessibility_spec.rb (same form, same Time & Place tab) and
# follows docs/development/accessibility_testing.md: axe over the region in every
# supported locale plus focused semantic assertions.
RSpec.describe 'Event location picker accessibility', :accessibility, :as_platform_manager, :js, retry: 0 do
  let(:platform_manager_user) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  def open_time_and_place_tab # rubocop:disable Metrics/AbcSize
    expect(page).to have_css('#event-form-tabs', wait: 10)
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show.active', wait: 5)
    expect(page).to have_css('select#event_location_picker', visible: :all, wait: 5)
    expect(page).to have_css('.location-fields .ss-main', wait: 5)
  end

  def visit_new_event(locale)
    visit better_together.new_event_path(locale:)
    return unless page.has_field?('user[email]', disabled: false)

    capybara_login_as_platform_manager
    visit better_together.new_event_path(locale:)
  end

  %i[en fr es uk].each do |locale|
    context "in #{locale}" do
      before do
        configure_host_platform
        capybara_login_as_platform_manager
        visit_new_event(locale)
        open_time_and_place_tab
      end

      it 'passes WCAG 2.1 AA with the picker collapsed', :aggregate_failures do
        expect(page).to be_axe_clean
          .within('#event-time-and-place')
          .excluding('.btn-outline-info')
          .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
      end

      it 'labels and describes the picker', :aggregate_failures do
        label = find('label[for="event_location_picker"]')
        expect(label.text).to eq(I18n.t('better_together.events.labels.location', locale:))

        described_by = find('select#event_location_picker', visible: :all)['aria-describedby']
        expect(described_by).to include('event_location_picker_hint')
        hint = find('#event_location_picker_hint')
        expect(hint.text).to eq(I18n.t('better_together.events.hints.location', locale:))
        expect(hint.text).not_to match(/translation missing/i)
      end

      it 'passes WCAG 2.1 AA with the inline address panel open', :aggregate_failures do
        within('.location-fields') { find('.ss-main', match: :first).click }
        find('.location-fields .ss-content .ss-search input', wait: 5).set('Test Venue')
        row = find('.ss-content .ss-option.ss-create-option', text: /create new/i, match: :first, wait: 10)
        page.execute_script('arguments[0].click()', row.native)

        panel = find('#event_location_new_address')
        expect(panel).to be_visible
        expect(panel).to have_css('legend',
                                  text: I18n.t('better_together.events.location_picker.new_address_legend', locale:))
        expect(page.evaluate_script('document.activeElement.closest("#event_location_new_address") !== null')).to be(true)

        expect(page).to be_axe_clean
          .within('#event_location_new_address')
          .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)

        within('#event_location_new_address') do
          click_button I18n.t('better_together.events.location_picker.cancel_new_address', locale:)
        end
        expect(page.evaluate_script('document.activeElement.classList.contains("ss-main")')).to be(true)
        expect(page).to have_css('[data-better_together--location-selector-target="announcement"]',
                                 text: I18n.t('better_together.events.location_picker.announcements.cancelled', locale:),
                                 visible: :all, wait: 5)
      end
    end
  end

  context 'when the form re-renders with a location error' do
    before do
      configure_host_platform
      capybara_login_as_platform_manager
      visit_new_event(I18n.default_locale)
      open_time_and_place_tab
    end

    it 'marks the picker invalid and exposes the error to assistive tech', :aggregate_failures do
      # Force a nested-address validation failure: reveal the panel, type only a
      # street line, submit.
      within('.location-fields') { find('.ss-main', match: :first).click }
      find('.location-fields .ss-content .ss-search input', wait: 5).set('9 Broken Rd')
      row = find('.ss-content .ss-option.ss-create-option', text: /create new/i, match: :first, wait: 10)
      page.execute_script('arguments[0].click()', row.native)

      within('#event_location_new_address') do
        # Leave physical/postal both unchecked -> Address#at_least_one_address_type fails.
        fill_in I18n.t('better_together.addresses.city_name'), with: 'Brokenville'
      end
      fill_in name: 'event[name_en]', with: 'Event that fails to save'
      within('form.form') { find('input[type="submit"], button[type="submit"]', match: :first).click }

      expect(page).to have_css('#event_location_picker_error[role="alert"]', wait: 10)
      expect(find('select#event_location_picker', visible: :all)['aria-invalid']).to eq('true')
    end
  end
end
