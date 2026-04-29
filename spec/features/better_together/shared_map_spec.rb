# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Shared map surfaces', :js do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  before do
    configure_host_platform
  end

  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  scenario 'communities index renders the shared map and supports layer toggles and geolocation' do
    community = create_mapped_community(name: 'Map Toggle Community')

    visit better_together.communities_path(locale:)
    wait_for_leaflet_map

    expect(page).to have_css('.leaflet-marker-icon', minimum: 1)

    state = leaflet_map_state
    expect(state['markerCount']).to be >= 1
    expect(state['hasOsmLayer']).to be(true)
    expect(state['hasSatelliteLayer']).to be(false)

    click_button 'Satellite'
    expect(leaflet_map_state['hasSatelliteLayer']).to be(true)
    expect(leaflet_map_state['hasOsmLayer']).to be(false)

    click_button 'Map'
    expect(leaflet_map_state['hasOsmLayer']).to be(true)
    expect(leaflet_map_state['hasSatelliteLayer']).to be(false)

    find('.leaflet-marker-icon', match: :first).click
    expect(page).to have_link(community.name, href: better_together.community_path(community, locale:))

    stub_browser_geolocation(latitude: 47.5615, longitude: -52.7126)
    click_button 'Geolocate Me'

    center = leaflet_map_state['center']
    expect(center['lat']).to be_within(0.001).of(47.5615)
    expect(center['lng']).to be_within(0.001).of(-52.7126)
  end

  scenario 'geography map show renders the shared map with an interactable marker' do
    community = create_mapped_community(name: 'Show Page Community')
    geography_map = create(
      :geography_map,
      creator: platform_manager.person,
      mappable: community,
      privacy: 'public',
      protected: false
    )

    capybara_login_as_platform_manager
    visit better_together.map_path(geography_map, locale:)
    wait_for_leaflet_map

    expect(leaflet_map_state['markerCount']).to be >= 1

    find('.leaflet-marker-icon', match: :first).click
    expect(page).to have_link(community.name, href: better_together.community_path(community, locale:))
  end

  scenario 'building-backed community pins use the existing leaflet_points popup content' do
    community = create_mapped_community(
      name: 'Building Pin Community',
      address_line1: '25 Civic Square',
      latitude: 44.6488,
      longitude: -63.5752
    )

    visit better_together.communities_path(locale:)
    wait_for_leaflet_map

    find('.leaflet-marker-icon', match: :first).click

    expect(page).to have_link(community.name, href: better_together.community_path(community, locale:))
    expect(page).to have_text('25 Civic Square')
    expect(leaflet_map_state['popupHtml']).to include(better_together.community_path(community, locale:))
  end

  def create_mapped_community(name:, address_line1: '62 Broadway', latitude: 48.9517, longitude: -57.9474)
    community = create(
      :better_together_community,
      :open_access,
      creator: platform_manager.person,
      name:,
      privacy: 'public'
    )
    building = create(
      :better_together_infrastructure_building,
      creator: platform_manager.person,
      name: "#{name} Hall",
      privacy: 'public',
      address: build(
        :better_together_address,
        line1: address_line1,
        city_name: 'Corner Brook',
        state_province_name: 'Newfoundland and Labrador',
        postal_code: 'A2H 4C2',
        country_name: 'Canada',
        privacy: 'public',
        primary_flag: true
      )
    )

    BetterTogether::Infrastructure::BuildingConnection.create!(
      building:,
      connection: community,
      position: 1,
      primary_flag: true
    )

    building.geospatial_space.space.assign_attributes(
      latitude:,
      longitude:
    )
    building.geospatial_space.save!

    community.reload
    community
  end
end
