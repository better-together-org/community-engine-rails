# frozen_string_literal: true

require 'rails_helper'

# Clustering, typed pins, the legend and the boundary layer of the shared map controller.
RSpec.feature 'Map clustering and layers', :js do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  before do
    configure_host_platform
    create_mapped_community(creator: platform_manager.person)
    visit better_together.communities_path(locale:)
    wait_for_leaflet_map
  end

  def point(index, lat:, lng:, **style)
    { lat:, lng:, elevation: nil, label: "Place #{index}", popup_html: "<b>Place #{index}</b>" }.merge(style)
  end

  # Replaces the map's points with these, through the controller's own methods.
  def show_points(points, types: [])
    page.execute_script(map_controller_script(<<~JS), '.map', points, types)
      const [points, types] = [arguments[1], arguments[2]]
      controller.map.removeLayer(controller.markerLayer)
      controller.typesValue = types
      controller.addPointsWithLabels(points)
      controller.addLegend()
    JS
  end

  def cluster_count
    page.all('.map .map-cluster', wait: 5).size
  end

  scenario 'groups nearby points into one cluster showing the count, and spreads out when zoomed in' do
    nearby = Array.new(5) { |i| point(i, lat: 48.9517 + (i * 0.00001), lng: -57.9474) }
    far = [point(9, lat: 49.5, lng: -56.0)]
    show_points(nearby + far)

    expect(page).to have_css('.map .map-cluster', text: '5')
    expect(page).to have_css('.map .leaflet-marker-icon.leaflet-interactive:not(.map-cluster)', minimum: 1)

    find('.map .map-cluster', text: '5').click
    expect(page).to have_css('.map .leaflet-marker-icon', minimum: 5, wait: 5)
  end

  scenario 'does not cluster when clustering is turned off' do
    page.execute_script(map_controller_script(<<~JS), '.map')
      controller.clusterValue = false
      controller.map.removeLayer(controller.markerLayer)
      controller.addPointsWithLabels(#{Array.new(4) { |i| point(i, lat: 48.9517, lng: -57.9474) }.to_json})
    JS

    expect(page).not_to have_css('.map .map-cluster')
    expect(page).to have_css('.map .leaflet-marker-icon', count: 4)
  end

  scenario 'draws pins with the type colour and icon, and a legend that shows and hides each type' do
    types = [{ key: 'Post', label: 'Posts', color: '#0d6efd' }, { key: 'Event', label: 'Events', color: '#198754' }]
    show_points([point(1, lat: 48.90, lng: -57.90, type: 'Post', color: '#0d6efd', icon: 'fa-newspaper'),
                 point(2, lat: 49.40, lng: -56.50, type: 'Event', color: '#198754', icon: 'fa-calendar-day')], types:)

    expect(page).to have_css('.map .map-pin span[style*="background"]', count: 2)
    expect(page).to have_css('.map .map-legend label', count: 2)

    uncheck 'Events'
    expect(page).to have_css('.map .map-pin', count: 1)

    check 'Events'
    expect(page).to have_css('.map .map-pin', count: 2)
  end

  scenario 'draws a cluster as a pie of its types' do
    types = [{ key: 'Post', label: 'Posts', color: '#0d6efd' }, { key: 'Event', label: 'Events', color: '#198754' }]
    show_points([point(1, lat: 48.9517, lng: -57.9474, type: 'Post'),
                 point(2, lat: 48.95171, lng: -57.9474, type: 'Event')], types:)

    expect(page).to have_css('.map .map-cluster span[style*="conic-gradient"]')
  end

  scenario 'draws a boundary outline when given GeoJSON' do
    geojson = { type: 'Polygon', coordinates: [[[-58.1, 48.9], [-57.8, 48.9], [-57.8, 49.1], [-58.1, 49.1], [-58.1, 48.9]]] }
    page.execute_script(map_controller_script(<<~JS), '.map', geojson)
      controller.boundaryValue = arguments[1]
      controller.addBoundary()
    JS

    expect(page).to have_css('.map svg path.leaflet-interactive, .map svg path[stroke="#0d6efd"]')
    expect(leaflet_map_state).to include('markerCount')
  end

  scenario 'keeps the layer toggle and a single pin popup working with clustering on' do
    find('.map .leaflet-marker-icon', match: :first).click
    expect(page).to have_css('.leaflet-popup', text: 'Mapped Community')

    click_button 'Satellite'
    expect(leaflet_map_state['hasSatelliteLayer']).to be(true)
  end
end
