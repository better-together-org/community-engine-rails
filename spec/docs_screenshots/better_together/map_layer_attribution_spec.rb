# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/map_layer_attribution_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/map_layer_attribution.*
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for map layer attribution',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::MapFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let(:layer) do
    BetterTogether::Geography::MapLayer.new(
      key: 'districts', attribution: 'Electoral Boundaries Commission', attribution_url: 'https://example.test/data',
      licence: 'Open Government Licence', licence_url: 'https://example.test/ogl',
      geojson: { 'type' => 'Polygon',
                 'coordinates' => [[[-58.0, 48.9], [-57.9, 48.9], [-57.9, 49.0], [-58.0, 49.0], [-58.0, 48.9]]] }
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create_mapped_community(creator: manager.person)
    allow_any_instance_of(BetterTogether::Geography::Map).to receive(:layers).and_return([layer]) # rubocop:disable RSpec/AnyInstance
  end

  after { Current.platform = nil }

  it 'captures the layer credit in the attribution control' do
    bullet = 'The credit comes from the layer itself and shows only while the layer is on the map.'
    BetterTogether::CapybaraScreenshotEngine.capture(
      'map_layer_attribution', device: :both,
                               metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'map_layer_attribution',
                                           flow: 'map_layer_attribution', source_spec: self.class.metadata[:file_path] },
                               callouts: [{ id: 'attribution', selector: '.leaflet-control-attribution', title: 'Layer attribution',
                                            bullets: [bullet] }],
                               narrative: {
                                 title: 'Map layer attribution', audience: %w[visitor developer],
                                 journey_step: 'As a visitor, I can see who provided the data drawn on a map and under which licence.',
                                 callouts: [{ id: 'attribution', title: 'Layer attribution', description: bullet }],
                                 accessibility_notes: 'Credits are real links with visible text.'
                               }
    ) do
      capybara_login_as_platform_manager
      visit better_together.communities_path(locale: I18n.default_locale)
      wait_for_leaflet_map
      expect(page).to have_css('.leaflet-control-attribution a', text: 'Electoral Boundaries Commission')
      page.execute_script("document.querySelector('.leaflet-control-attribution').scrollIntoView({block: 'center'})")
    end
  end
end
