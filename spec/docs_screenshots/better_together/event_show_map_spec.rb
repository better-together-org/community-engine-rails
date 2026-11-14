# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/event_show_map_spec.rb'
RSpec.describe 'Documentation screenshots for the event page map column', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', host_url: 'http://www.example.com') }
  end
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:event) do
    create(:better_together_event, :with_address_location, platform: host_platform, creator: manager.person,
                                                           name: 'Harbour Arts Night',
                                                           description: 'An evening of music and poetry.')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:geography_geospatial_space, geospatial: event.location.location,
                                        space: create(:geography_space, latitude: 48.95, longitude: -57.95))
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'event_show_map', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_event
    capybara_login_as_platform_manager
    visit better_together.event_path(event, locale:)
    expect(page).to have_css('#event-map [data-controller="better_together--map"]')
    page.execute_script("document.getElementById('event-map').scrollIntoView({block: 'center'})")
  end

  it 'captures the map beside the tabs' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_show_map', device: :both, metadata: metadata('map_column'),
                        callouts: [
                          { id: 'tabs', selector: '#event-tabbed-section', title: 'Details',
                            bullets: ['Date, location, hosts and description keep the wider column.'] },
                          { id: 'map', selector: '#event-map', title: 'Map',
                            bullets: ['Beside the tabs on wide screens, below them on narrow ones.'] }
                        ],
                        narrative: {
                          title: 'Event page, map column',
                          audience: %w[event_attendee developer],
                          journey_step: 'As an attendee, I read about an event and see where it is.',
                          callouts: [
                            { id: 'tabs', title: 'Details', description: 'The tab column shrinks to make room.' },
                            { id: 'map', title: 'Map', description: 'Rendered once the place is geocoded.' }
                          ],
                          accessibility_notes: 'The map section is labelled with the event name.'
                        }
    ) do
      visit_event
      expect(page).to have_css('#event-map')
    end
  end

  it 'captures the plain map column' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_show_map_plain', device: :both, metadata: metadata('map_column_plain')
    ) do
      visit_event
      expect(page).to have_css('#event-map')
    end
  end
end
