# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/event_location_picker_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/event_location_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the event location picker',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'event_location_picker',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def open_time_and_place_tab
    find('#event-time-and-place-tab').click
    expect(page).to have_css('#event-time-and-place.show')
  end

  # Opens the picker, types a term, and waits for the debounced results (the
  # "Create new ..." rows are appended once a term is present).
  def search_picker(term)
    within('.location-fields') { find('.ss-main', match: :first).click }
    find('.location-fields .ss-content .ss-search input', wait: 5).set(term)
    expect(page).to have_css('.ss-content .ss-option.ss-create-option', wait: 10)
  end

  it 'captures the mixed-search picker showing live results across location types' do
    settlement = create(:geography_settlement, name: 'Corner Brook')
    address_event = create(:better_together_event, :with_address_location, platform: host_platform,
                                                                           creator: manager.person,
                                                                           name: 'Corner Meetup')
    address_event.location.location.update!(city_name: 'Corner Brook')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_picker_search',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_picker_search', role: 'event_organizer'),
      callouts: [
        {
          id: 'location_picker',
          selector: '#event_location_picker',
          title: 'One field searches everything',
          bullets: [
            'One field searches Address, Building, Floor, Room, Settlement, and Region at once as you type.',
            'No location-type picker to choose first: results are labeled with their type.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Mixed-Search Location Picker',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, I type a few letters of the venue name and see matching ' \
                      'addresses, buildings, and curated places together in one list, instead of first ' \
                      'having to know and pick which kind of location it is.',
        callouts: [
          {
            id: 'location_picker',
            title: 'Mixed-type search',
            description: 'EventsController#available_locations searches every Geography::Placeable type ' \
                         'at once when no location_type is given, returning composite "ClassName:id" ' \
                         'values so one merged, type-labeled result list can span types without id ' \
                         'collisions. The allow-list is read from Placeable.included_in_models, so a ' \
                         'future new location type is searched here automatically with no view change.'
          }
        ],
        accessibility_notes: 'The field has a single "Location" label and one hint wired via ' \
                             'aria-describedby. The combobox is keyboard-operable (type-ahead, arrow ' \
                             'keys, Enter to select) and exposes role="combobox" to assistive technology.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('select#event_location_picker', visible: :all, wait: 10)
      expect(page).to have_css('.location-fields .ss-main', wait: 5)

      within('.location-fields') do
        find('.ss-main', match: :first).click
      end

      expect(page).to have_content(settlement.name, wait: 10)
      expect(page).to have_content(address_event.location.location.city_name, wait: 10)
    end
  end

  it 'captures an event with an existing settlement already assigned' do
    settlement = create(:geography_settlement, name: 'Corner Brook')
    event = create(:better_together_event, platform: host_platform, creator: manager.person,
                                           name: 'Community Meetup')
    event.create_location!(location: settlement, location_type: 'BetterTogether::Geography::Settlement')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_settlement_assigned',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_settlement_assigned', role: 'event_organizer'),
      callouts: [
        {
          id: 'location_picker',
          selector: '#event_location_picker',
          title: 'Currently assigned location',
          bullets: [
            'Pre-selected with a composite value ("BetterTogether::Geography::Settlement:<id>") built ' \
            'server-side from the event\'s existing location.',
            'The organizer can search for a different location in the same field without a separate mode switch.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Settlement Already Assigned',
        audience: %w[event_organizer community_organizer platform_organizer developer],
        journey_step: 'As an event organizer editing an existing event, I see which settlement is ' \
                      'currently assigned and can search for a different one without leaving the form.',
        callouts: [
          {
            id: 'location_picker',
            title: 'Splitting the composite value back apart',
            description: 'location_selector_controller#applyLocationSelection splits a picked composite ' \
                         'value back into the plain location_id/location_type hidden fields ' \
                         'LocatableLocation\'s ordinary polymorphic assignment already expects — no change ' \
                         'was needed to that assignment path itself.'
          }
        ],
        accessibility_notes: 'The search combobox is keyboard-operable (type-ahead, arrow keys, Enter to ' \
                             'select) and exposes role="combobox" to assistive technology.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_event_path(event, locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('.location-fields .ss-main', text: settlement.name, wait: 5)
    end
  end

  it 'captures the "Create new address" action row inside the search results' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_create_row',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_create_row', role: 'event_organizer'),
      callouts: [
        {
          id: 'create_row',
          selector: '.ss-content .ss-option.ss-create-option',
          title: 'Creation lives in the results list',
          bullets: [
            'Type an address that is not on file and the last rows offer "Create new address" and ' \
            '"use your typed text as a custom name".',
            'No separate always-present button next to the field.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Create From the Search Results',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, when nothing in the list is my venue, I create it right ' \
                      'from the same search rather than reaching for a separate button.',
        callouts: [
          {
            id: 'create_row',
            title: 'Synthetic action rows',
            description: 'slim_select_controller.js (opt-in createOptions) appends "Create new address" ' \
                         'and, when the typed text has no exact match, a "use as a custom name" row to ' \
                         'every AJAX result set. Picking one is intercepted by beforeChange and ' \
                         'dispatched as better_together--slim-select:create rather than selected. Only ' \
                         'Address is inline-creatable; Building, Settlement, and Region are chosen from ' \
                         'the existing set only.'
          }
        ],
        accessibility_notes: 'The action rows are real listbox options (role="option"), reachable by ' \
                             'the same arrow-key / Enter interaction as any search result, and their ' \
                             'visible text matches their accessible name.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('select#event_location_picker', visible: :all, wait: 10)
      expect(page).to have_css('.location-fields .ss-main', wait: 5)
      search_picker('Rossignol Hall')
    end
  end

  it 'captures the revealed inline "new address" fieldset' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_new_address_panel',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_new_address_panel', role: 'event_organizer'),
      callouts: [
        {
          id: 'new_address_panel',
          selector: '#event_location_new_address',
          title: 'One labelled inline address form',
          bullets: [
            'A <fieldset> with a <legend> ("New address" plus the text you typed).',
            'Line 1 is prefilled from your search term; Cancel closes it and returns focus to the search field.',
            'Saved together with the event in a single submit.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Inline New Address Panel',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, after choosing "Create new address" I fill in the address ' \
                      'right here instead of being sent to a separate address-management screen first.',
        callouts: [
          {
            id: 'new_address_panel',
            title: 'Focus and state management',
            description: 'revealNewRecord resets the picker, unhides and enables the fieldset, prefills ' \
                         'line1 from the typed term, sets the legend caption, and moves focus into the ' \
                         'fieldset. Picking an existing location or cancelling closes it, disables its ' \
                         'fields, and clears the hidden location fields so they never compete on submit. ' \
                         'On a validation error the fieldset is re-rendered open with the typed input ' \
                         'preserved.'
          }
        ],
        accessibility_notes: 'The panel is a <fieldset>/<legend> region; focus moves into it on reveal ' \
                             'and back to the combobox on Cancel, and both transitions are announced in ' \
                             'a visually-hidden role="status" live region. The nested label and privacy ' \
                             'selects are not HTML "required" in this inline context, so a visible-but-' \
                             'untouched panel never silently blocks the event form submit.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('select#event_location_picker', visible: :all, wait: 10)
      expect(page).to have_css('.location-fields .ss-main', wait: 5)
      search_picker('124 Water Street')
      row = find('.ss-content .ss-option.ss-create-option', text: /create new/i, match: :first, wait: 10)
      page.execute_script('arguments[0].click()', row.native)

      panel = find('#event_location_new_address', visible: true)
      # The revealed panel's fields push it below the fold - scroll it into view
      # or its bounding rect falls outside the captured image and the callout is
      # silently dropped.
      page.scroll_to(panel, align: :center)
    end
  end
end
