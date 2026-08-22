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
            'Replaces the old location-type radio group entirely.',
            'Searches Address, Building, Floor, Room, Settlement, and Region at once as you type.'
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
            description: 'New in this PR: EventsController#available_locations searches every ' \
                         'Geography::Placeable type at once when no location_type is given, returning ' \
                         'composite "ClassName:id" values so one merged, type-labeled result list can span ' \
                         'types without id collisions. The allow-list is read from ' \
                         'Placeable.included_in_models, so a future new location type is searched here ' \
                         'automatically with no view change.'
          }
        ],
        accessibility_notes: 'The search combobox is keyboard-operable (type-ahead, arrow keys, Enter to ' \
                             'select) and exposes role="combobox" to assistive technology.'
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

  it 'captures the inline "add a new address" panel' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_location_address_new_panel',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_location_address_new_panel', role: 'event_organizer'),
      callouts: [
        {
          id: 'new_address_panel',
          selector: '[data-better_together--location-selector-target="newRecordBlock"][data-location-type="address"]',
          title: 'Inline address fields',
          bullets: [
            'Revealed by the "+ New" link next to the search field — always available now, not gated ' \
            'behind picking "Address" from a radio group first.',
            'The new address is saved together with the event in a single submit.'
          ]
        }
      ],
      narrative: {
        title: 'Event Form — Create a New Address Inline',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, if the venue address isn\'t in the system yet, I add it ' \
                      'right here instead of being sent to a separate address-management screen first.',
        callouts: [
          {
            id: 'new_address_button',
            title: '"+ New" trigger',
            description: 'Only shown when the organizer has permission to create addresses ' \
                         '(Pundit-gated). Settlement and Region have no equivalent button — they are ' \
                         'curated reference data, chosen from the existing list only, never created here. ' \
                         'Changed in this PR: previously only appeared after selecting the matching radio ' \
                         '— a user reaches for "+New" precisely when nothing in search matches, so it is ' \
                         'now always available regardless of what the picker currently holds.'
          },
          {
            id: 'new_address_panel',
            title: 'Inline creation fields',
            description: 'Picking an existing location, or typing a new simple name, automatically closes ' \
                         'this panel and disables its fields again so they never compete with the ' \
                         'just-picked location on submit.'
          }
        ],
        accessibility_notes: 'The "+ New" control is a real link with visible focus state; the revealed ' \
                             'panel receives programmatic focus on its first field when opened.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_event_path(locale: I18n.default_locale)
      open_time_and_place_tab

      expect(page).to have_css('.location-fields .ss-main')
      find('a[data-location-type="address"]', match: :first).click

      panel = find(
        '[data-better_together--location-selector-target="newRecordBlock"][data-location-type="address"]',
        visible: true
      )
      # The revealed panel's own fields (label, privacy, physical/postal,
      # line1..country) push it below the fold — scroll it into view or its
      # bounding rect falls outside the captured image and the callout is
      # silently dropped (clip_rect rejects any target with zero on-screen
      # height/width after clipping to image bounds).
      page.scroll_to(panel, align: :center)
    end
  end
end
