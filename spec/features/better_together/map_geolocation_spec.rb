# frozen_string_literal: true

require 'rails_helper'

# The "Geolocate Me" button on every shared map. Real browser permission and position handling (through the Chrome
# DevTools Protocol) covers the success and permission denied paths; scripted navigator.geolocation covers the error
# kinds, the retry rule and the missing API. Every example also asserts that no alert() is ever shown.
RSpec.feature 'Map geolocation', :js do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  let(:coarse_attempt) { { 'enableHighAccuracy' => false, 'timeout' => 15_000, 'maximumAge' => 300_000 } }
  let(:precise_attempt) { { 'enableHighAccuracy' => true, 'timeout' => 30_000, 'maximumAge' => 0 } }
  let(:position) { { latitude: 47.5615, longitude: -52.7126, accuracy: 30 } }

  before do
    configure_host_platform
    create_mapped_community(creator: platform_manager.person)
    visit better_together.communities_path(locale:)
    wait_for_leaflet_map
    record_browser_alerts
  end

  def map_status
    find('.map .map-status', visible: :all).text(:all)
  end

  def tap_geolocate
    click_button 'Geolocate Me'
  end

  scenario 'recentres on the browser position when location is allowed' do
    grant_browser_geolocation(latitude: 47.5615, longitude: -52.7126, accuracy: 20)

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="located"]')
    state = leaflet_map_state
    expect(state['center']['lat']).to be_within(0.001).of(47.5615)
    expect(state['center']['lng']).to be_within(0.001).of(-52.7126)
    expect(state['zoom']).to eq(13)
    expect(state['positionShown']).to be(true)
    expect(map_status).to eq('Showing your location.')
    expect(browser_alerts).to be_empty
  end

  scenario 'says location is blocked, and does not move the map, when the browser refuses it' do
    before_center = leaflet_map_state['center']
    deny_browser_geolocation

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="denied"]')
    expect(map_status).to include('Location access is blocked')
    expect(leaflet_map_state['center']['lat']).to eq(before_center['lat'])
    expect(leaflet_map_state['positionShown']).to be(false)
    expect(browser_alerts).to be_empty
  end

  scenario 'asks for a coarse, cached position first so a slow first fix or a slow permission answer does not fail' do
    script_browser_geolocation({ position: position })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="located"]')
    expect(geolocation_calls).to eq([coarse_attempt])
  end

  scenario 'retries once with high accuracy after a timeout, and recovers' do
    script_browser_geolocation({ error: 3 }, { position: position })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="located"]')
    expect(geolocation_calls).to eq([coarse_attempt, precise_attempt])
    expect(leaflet_map_state['center']['lat']).to be_within(0.001).of(47.5615)
    expect(browser_alerts).to be_empty
  end

  scenario 'retries once after an unavailable position, then reports it' do
    script_browser_geolocation({ error: 2 }, { error: 2 })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="unavailable"]')
    expect(geolocation_calls).to eq([coarse_attempt, precise_attempt])
    expect(map_status).to include('could not be determined')
    expect(browser_alerts).to be_empty
  end

  scenario 'reports a timeout when both attempts time out' do
    script_browser_geolocation({ error: 3 }, { error: 3 })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="timeout"]')
    expect(map_status).to include('took too long')
    expect(browser_alerts).to be_empty
  end

  scenario 'does not retry when permission is denied' do
    script_browser_geolocation({ error: 1 }, { position: position })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="denied"]')
    expect(geolocation_calls.size).to eq(1)
    expect(browser_alerts).to be_empty
  end

  scenario 'says so when the browser has no geolocation support' do
    remove_browser_geolocation

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="unsupported"]')
    expect(map_status).to eq('Your browser does not support location.')
    expect(browser_alerts).to be_empty
  end

  scenario 'shows a busy state while locating and ignores a second tap' do
    script_browser_geolocation({ pending: true })

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="locating"]')
    expect(page).to have_css('[data-geolocation-button][aria-busy="true"]')
    expect(map_status).to eq('Finding your location...')
    tap_geolocate
    expect(geolocation_calls.size).to eq(1)
  end

  scenario 'can be tried again after an error' do
    script_browser_geolocation({ error: 1 }, { position: position })
    tap_geolocate
    expect(page).to have_css('.map[data-geolocation-state="denied"]')

    tap_geolocate

    expect(page).to have_css('.map[data-geolocation-state="located"]')
  end
end
