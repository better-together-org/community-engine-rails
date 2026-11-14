# frozen_string_literal: true

require 'rails_helper'

# A layer's credit is in the map's attribution control exactly while the layer is on the map, with no per-map step.
RSpec.feature 'Map layer attribution', :js do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let(:geojson) do
    { 'type' => 'Polygon', 'coordinates' => [[[-58.0, 48.9], [-57.9, 48.9], [-57.9, 49.0], [-58.0, 48.9]]] }
  end
  let(:layer) do
    BetterTogether::Geography::MapLayer.new(key: 'districts', geojson:, attribution: 'Boundaries Commission',
                                            attribution_url: 'https://example.test/src', licence: 'OGL')
  end

  before do
    configure_host_platform
    create_mapped_community(creator: platform_manager.person)
    allow_any_instance_of(BetterTogether::Geography::Map).to receive(:layers).and_return([layer]) # rubocop:disable RSpec/AnyInstance
  end

  scenario 'credits the layer data in the attribution control', :aggregate_failures do
    visit better_together.communities_path(locale:)
    wait_for_leaflet_map

    expect(page).to have_css('.leaflet-overlay-pane path')
    expect(page).to have_css('.leaflet-control-attribution a[href="https://example.test/src"]',
                             text: 'Boundaries Commission')
    expect(page).to have_css('.leaflet-control-attribution', text: 'OGL')
    expect(page).to have_css('.leaflet-control-attribution', text: 'OpenStreetMap')
  end
end
