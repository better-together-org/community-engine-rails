# frozen_string_literal: true

module BetterTogether
  # Drives the address form's geography selects through the event form's inline new-address panel.
  module AddressGeographyHelpers
    PANEL = '#event_location_new_address'

    def open_new_address_panel(query = '1 Main St')
      visit better_together.new_event_path(locale: I18n.default_locale)
      find('#event-time-and-place-tab').click
      expect(page).to have_css('.location-fields .ss-main', wait: 10)
      search_location_picker(query)
      click_create_new_address
      find(PANEL, visible: true)
    end

    def geography_panel
      "#{PANEL} .address-geography-fields"
    end

    def geography_ss_id(level)
      find("#{geography_panel} select[id$='_#{level}_select']", visible: :all)['data-id']
    end

    # Opens a level's dropdown and waits for its options.
    def open_geography_select(level)
      ss_id = geography_ss_id(level)
      find("#{geography_panel} .ss-main[data-id='#{ss_id}']", match: :first).click
      ss_id
    end

    def choose_geography(level, text)
      ss_id = open_geography_select(level)
      expect(page).to have_css("div.ss-content[data-id='#{ss_id}'] .ss-option", text:, wait: 10)
      find("div.ss-content[data-id='#{ss_id}'] .ss-option", text:, match: :first).click
    end

    def geography_hidden(level, kind)
      find("#{geography_panel} input[data-better_together--address-geography-target='#{level}#{kind}']",
           visible: :all).value
    end

    private

    def click_create_new_address
      row = find("div.ss-content[data-id='#{location_picker_ss_id}'] " \
                 '.ss-option.ss-create-option:not(.ss-create-option--simple)', match: :first, wait: 10)
      page.execute_script('arguments[0].click()', row.native)
    end

    def location_picker_ss_id
      find('select#event_location_picker', visible: :all)['data-id']
    end

    def search_location_picker(query)
      within('.location-fields') { find('.ss-main', match: :first).click }
      within("div.ss-content[data-id='#{location_picker_ss_id}']", visible: :all) { find('.ss-search input').set(query) }
    end
  end
end
