# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Locatable::LocationMapPoints do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:community) { create(:better_together_community) }
  let(:address) { create(:better_together_address) }
  let(:place) { create(:geography_space, latitude: 48.95, longitude: -57.95) }

  def locate(community, address, name: nil)
    community.create_location!(location: address, name:)
    community.reload
  end

  def geocode(address, space)
    create(:geography_geospatial_space, geospatial: address, space:)
  end

  it 'has no points without a location' do
    expect([community.leaflet_points, community.spaces]).to all(be_empty)
  end

  it 'has no points when the place is not geocoded' do
    locate(community, address)

    expect([community.leaflet_points, community.spaces]).to all(be_empty)
  end

  it 'shows the located place when it is geocoded', :aggregate_failures do
    geocode(address, place)
    locate(community, address, name: 'Harbour Hall')

    expect(community.spaces).to eq([place])
    expect(community.leaflet_points.first).to include(lat: 48.95, lng: -57.95)
    expect(community.leaflet_points.first[:popup_html]).to include('Harbour Hall')
  end

  it 'escapes the community name in the popup' do
    geocode(address, place)
    community.update!(name: '<b>Bold</b> Co-op')
    locate(community, address)

    expect(community.leaflet_points.first[:label]).not_to include('<b>')
  end
end
