# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Event location selector', :as_platform_manager, :js do
  # rubocop:todo RSpec/ExampleLength
  scenario 'shows inline new address and building blocks', skip: 'temporarily disabled (location selector flakiness)' do
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.new_event_path(locale: I18n.default_locale)

    fill_in name: 'event[name_en]', with: 'Test Event'
    find('#event-time-and-place-tab').click

    # Ensure Stimulus controller is present
    expect(page).to have_selector('[data-controller="better_together--location-selector"]')

    # Switch to Address location type by clicking its label (works around click interception)
    find('label[for="address_location"]', visible: :all).click

    within('[data-better_together--location-selector-target="addressLocation"]') do
      # Click the inline "New" button to reveal new address fields
      find('a.btn', text: I18n.t('better_together.events.actions.create_new_short', default: 'New'),
                    match: :first).click
    end

    # Assert the new address block is visible
    expect(page).to have_selector('[data-better_together--location-selector-target="newAddress"]', visible: true)

    # Switch to Building location type by clicking its label
    find('label[for="building_location"]', visible: :all).click

    within('[data-better_together--location-selector-target="buildingLocation"]') do
      # Click the inline "New" button to reveal new building fields
      find('a.btn', text: I18n.t('better_together.events.actions.create_new_short', default: 'New'),
                    match: :first).click
    end

    # Assert the new building block is visible
    expect(page).to have_selector('[data-better_together--location-selector-target="newBuilding"]', visible: true)
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:todo RSpec/ExampleLength
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'creates event with new address when saving', skip: 'temporarily disabled (location selector flakiness)' do
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.new_event_path(locale: I18n.default_locale)

    fill_in name: 'event[name_en]', with: 'Event with New Address'
    find('#event-time-and-place-tab').click

    expect(page).to have_selector('[data-controller="better_together--location-selector"]')

    # Switch to Address and open inline new form
    find('label[for="address_location"]', visible: :all).click

    within('[data-better_together--location-selector-target="addressLocation"]') do
      find('a.btn', text: I18n.t('better_together.events.actions.create_new_short', default: 'New'),
                    match: :first).click
    end

    within('[data-better_together--location-selector-target="newAddress"]') do
      # Fill required address fields
      fill_in I18n.t('better_together.addresses.line1'), with: '123 Test St'
      fill_in I18n.t('better_together.addresses.city_name'), with: 'Testville'
      fill_in I18n.t('better_together.addresses.postal_code'), with: 'T3ST 1NG'
      check I18n.t('better_together.addresses.physical')
      check I18n.t('better_together.addresses.postal')
    end

    address_count = BetterTogether::Address.count
    within('form.form') do
      # Scope to the form submit to avoid ambiguous matches when multiple toolbars/buttons exist
      find('input[type="submit"], button[type="submit"]', match: :first).click
    end

    # Wait for persistence and association
    expect(BetterTogether::Address.count).to eq(address_count + 1)
    event = BetterTogether::Event.order(:created_at).last
    expect(event.location).to be_a(BetterTogether::Address)
    expect(event.location.line1).to eq('123 Test St')
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:todo RSpec/ExampleLength
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'creates event with new building when saving', skip: 'temporarily disabled (location selector flakiness)' do
    # rubocop:enable RSpec/MultipleExpectations
    visit better_together.new_event_path(locale: I18n.default_locale)

    fill_in name: 'event[name_en]', with: 'Event with New Building'
    find('#event-time-and-place-tab').click

    expect(page).to have_selector('[data-controller="better_together--location-selector"]')

    # Switch to Building and open inline new form
    find('label[for="building_location"]', visible: :all).click

    within('[data-better_together--location-selector-target="buildingLocation"]') do
      find('a.btn', text: I18n.t('better_together.events.actions.create_new_short', default: 'New'),
                    match: :first).click
    end

    within('[data-better_together--location-selector-target="newBuilding"]') do
      # Fill building address required fields
      fill_in I18n.t('better_together.addresses.line1'), with: '456 Building Rd'
      fill_in I18n.t('better_together.addresses.city_name'), with: 'Buildtown'
      fill_in I18n.t('better_together.addresses.postal_code'), with: 'B1LD 1NG'
      check I18n.t('better_together.addresses.physical')
      check I18n.t('better_together.addresses.postal')

      # Attempt to set a building name if present in the form
      if page.has_selector?('input[name*="[name]"]', wait: 0.5)
        find('input[name*="[name]"]', match: :first).set('Test Building')
      end
    end

    building_count = BetterTogether::Infrastructure::Building.count
    within('form.form') do
      find('input[type="submit"], button[type="submit"]', match: :first).click
    end

    expect(BetterTogether::Infrastructure::Building.count).to eq(building_count + 1)
    event = BetterTogether::Event.order(:created_at).last
    expect(event.location).to be_a(BetterTogether::Infrastructure::Building)
    expect(event.location.address.line1).to eq('456 Building Rd')
  end
  # rubocop:enable RSpec/ExampleLength
end
