# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Event location selector', :as_platform_manager, :js do
  # Waits for the underlying <select> (SlimSelect hides it) before waiting for
  # SlimSelect's own wrapper - see AGENTS.md "SlimSelect Feature Spec Pattern".
  def wait_for_location_picker
    expect(page).to have_css('select#event_location_picker', visible: :all, wait: 10)
    expect(page).to have_css('.location-fields .ss-main', wait: 5)
  end

  # Matches the stabilizing wait pattern established in
  # timezone_datetime_form_spec.rb for this same form.
  def wait_for_event_form_ready
    expect(page).to have_css('#event-form-tabs', wait: 10)
    expect(page).to have_field('event[name_en]', wait: 10)
  end

  def open_location_time_tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show', wait: 10)
  end

  # Types into the SlimSelect search box and waits for the debounced AJAX results
  # (the "Create new ..." rows are always appended once a term is present).
  def type_in_picker(term)
    within('.location-fields') { find('.ss-main', match: :first).click }
    find('.location-fields .ss-content .ss-search input', wait: 5).set(term)
    expect(page).to have_css('.ss-content .ss-option.ss-create-option', wait: 10)
  end

  def choose_create_row(pattern)
    row = find('.ss-content .ss-option.ss-create-option', text: pattern, match: :first, wait: 10)
    page.execute_script('arguments[0].click()', row.native)
  end

  def pick_location_result(text)
    within('.location-fields') { find('.ss-main', match: :first).click }
    expect(page).to have_content(text, wait: 10)
    option = find('.ss-option', text: text, match: :first)
    page.execute_script('arguments[0].click()', option.native)
  end

  def address_panel
    find('#event_location_new_address', visible: :all)
  end

  scenario 'the Create new address row reveals a single labelled address panel' do
    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event with a brand-new address'
    open_location_time_tab
    wait_for_location_picker

    # No inline Building creation anywhere in the picker.
    expect(page).to have_no_css('[data-location-type="building"]', visible: :all)
    expect(address_panel).not_to be_visible

    type_in_picker('Bright Hall')
    choose_create_row(/create new .*address/i)

    expect(address_panel).to be_visible
    within('#event_location_new_address') do
      expect(page).to have_css('legend', text: I18n.t('better_together.events.location_picker.new_address_legend'))
      expect(page).to have_css('[data-better_together--location-selector-target="newRecordQuery"]', text: 'Bright Hall')
      expect(find('input[name*="[line1]"]').value).to eq('Bright Hall')
    end
  end

  scenario 'Cancel closes the address panel and returns focus to the combobox' do
    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event where the organizer changes their mind'
    open_location_time_tab
    wait_for_location_picker

    type_in_picker('Nowhere St')
    choose_create_row(/create new .*address/i)
    expect(address_panel).to be_visible

    within('#event_location_new_address') { click_button I18n.t('better_together.events.location_picker.cancel_new_address') }

    expect(address_panel).not_to be_visible
    expect(find("input[name='event[location_attributes][location_id]']", visible: :all).value).to be_blank
    expect(find("input[name='event[location_attributes][location_type]']", visible: :all).value).to be_blank
    expect(find("input[name='event[location_attributes][name]']", visible: :all).value).to be_blank
    expect(page).to have_css('[data-better_together--location-selector-target="announcement"]',
                             text: I18n.t('better_together.events.location_picker.announcements.cancelled'),
                             visible: :all, wait: 5)
    expect(page.evaluate_script('document.activeElement.classList.contains("ss-main")')).to be(true)
  end

  scenario 'picking an existing result closes an open create panel' do
    settlement = create(:geography_settlement)

    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event that ends up at a settlement'
    open_location_time_tab
    wait_for_location_picker

    type_in_picker('Some Draft Address')
    choose_create_row(/create new .*address/i)
    expect(address_panel).to be_visible

    pick_location_result(settlement.name)

    expect(address_panel).not_to be_visible
    location_type_field = find("input[name='event[location_attributes][location_type]']", visible: :all)
    expect(location_type_field.value).to eq('BetterTogether::Geography::Settlement')
  end

  scenario 'the typed-text row assigns a simple named location' do
    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event in an unlisted place'
    open_location_time_tab
    wait_for_location_picker

    type_in_picker('My Backyard')
    choose_create_row(/use .*My Backyard.* as a custom location name/i)

    expect(address_panel).not_to be_visible
    expect(find("input[name='event[location_attributes][name]']", visible: :all).value).to eq('My Backyard')
    expect(find("input[name='event[location_attributes][location_id]']", visible: :all).value).to be_blank
    expect(find("input[name='event[location_attributes][location_type]']", visible: :all).value).to be_blank
  end

  scenario 'picking a structured location clears a previously typed simple name' do
    settlement = create(:geography_settlement)

    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event switching location kinds'
    open_location_time_tab
    wait_for_location_picker

    simple_name_field = find("input[name='event[location_attributes][name]']", visible: :all)
    expect(simple_name_field.value).to be_blank

    pick_location_result(settlement.name)

    location_type_field = find("input[name='event[location_attributes][location_type]']", visible: :all)
    expect(location_type_field.value).to eq('BetterTogether::Geography::Settlement')
    expect(simple_name_field.value).to be_blank
  end

  # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
  scenario 'creates an event with a brand-new inline address', retry: 1 do
    # With inline: true the nested label/privacy selects are no longer HTML
    # `required` and the label defaults to "main", so line1 plus the address-type
    # switches are all the organizer must supply. The end-to-end
    # params -> LocatableLocation#location_attributes= -> Address build+autosave
    # path also has request-spec coverage in events_controller_spec.rb; if the
    # post-submit DOM observation races here (a pre-existing CSP-port /
    # host-setup flake in this file), fall back to that.
    visit better_together.new_event_path(locale: I18n.default_locale)
    wait_for_event_form_ready

    fill_in name: 'event[name_en]', with: 'Event with New Address'
    open_location_time_tab
    wait_for_location_picker

    type_in_picker('123 Test St')
    choose_create_row(/create new .*address/i)

    within('#event_location_new_address') do
      fill_in I18n.t('better_together.addresses.city_name'), with: 'Testville'
      fill_in I18n.t('better_together.addresses.postal_code'), with: 'T3ST 1NG'
      check I18n.t('better_together.addresses.physical')
      check I18n.t('better_together.addresses.postal')
    end

    address_count = BetterTogether::Address.count
    within('form.form') { find('input[type="submit"], button[type="submit"]', match: :first).click }

    expect(page).to have_current_path(%r{/events/[^/]+\z}, wait: 15)
    expect(BetterTogether::Address.count).to eq(address_count + 1)

    event = BetterTogether::Event.order(:created_at).last
    expect(event.location.location).to be_a(BetterTogether::Address)
    expect(event.location.location.line1).to eq('123 Test St')
  end
  # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
end
