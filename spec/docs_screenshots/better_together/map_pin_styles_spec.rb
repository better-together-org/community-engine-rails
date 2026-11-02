# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/map_pin_styles_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/map_pin_styles.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for map pin styles',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:types) do
    [{ key: 'Venue', label: 'Venues', color: '#6f42c1',
       pin: { color: '#6f42c1', shape: 'rounded', icons: ['fa-music', { icon: 'fa-circle-plus', color: '#ffd43b' }] } },
     { key: 'Office', label: 'Council offices', color: '#198754',
       pin: { color: '#198754', shape: 'square', icons: ['fa-landmark'] } }]
  end
  let(:points) do
    [{ lat: 48.97, lng: -58.00, type: 'Venue', label: 'Venue', popup_html: 'Venue' },
     { lat: 48.93, lng: -57.92, type: 'Venue', label: 'Venue', popup_html: 'Venue' },
     { lat: 48.95, lng: -57.96, type: 'Office', label: 'Office', popup_html: 'Office' },
     { lat: 48.99, lng: -57.90, label: 'Large', popup_html: 'Large',
       pin: { color: '#dc3545', size: 'lg', icons: ['fa-fire', { icon: 'fa-star', color: '#fff', scale: 0.5 }] } }]
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create_mapped_community(creator: manager.person)
  end

  after { Current.platform = nil }

  it 'captures stacked icons, shapes, sizes and a legend' do
    callouts = [{ id: 'pins', selector: '.map', title: 'Pin styles',
                  bullets: ['Stacked icons, shapes and sizes, set per point or per type.'] }]
    narrative = { title: 'Map pin styles', audience: %w[developer],
                  journey_step: 'As a developer, I can style map pins with stacked Font Awesome icons.',
                  callouts: [{ id: 'pins', title: 'Pin styles', description: 'A type sets the default look of its points.' }],
                  accessibility_notes: 'Pins are decorative; popups and the legend carry the names.' }
    metadata = { locale: I18n.default_locale, role: 'visitor', feature_set: 'map_pin_styles', flow: 'map_pin_styles',
                 source_spec: self.class.metadata[:file_path] }

    BetterTogether::CapybaraScreenshotEngine.capture('map_pin_styles', device: :both, metadata:, narrative:, callouts:) do
      capybara_login_as_platform_manager
      visit better_together.communities_path(locale: I18n.default_locale)
      wait_for_leaflet_map
      page.execute_script(map_controller_script(<<~JS), '.map', points, types)
        const [points, types] = [arguments[1], arguments[2]]
        controller.map.removeLayer(controller.markerLayer)
        controller.clusterValue = false
        controller.typesValue = types
        controller.addPointsWithLabels(points)
        controller.addLegend()
      JS
      expect(page).to have_css('.map .map-pin .fa-stack', minimum: 2)
      page.execute_script("document.querySelector('.map').scrollIntoView({block: 'center'})")
    end
  end
end
