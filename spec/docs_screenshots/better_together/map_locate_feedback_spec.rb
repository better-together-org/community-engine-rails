# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/map_locate_feedback_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/map_locate_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for map locate-me feedback',
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
  let(:position) { { latitude: 48.9517, longitude: -57.9474, accuracy: 60 } }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create_mapped_community(creator: manager.person)
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(slug)
    { locale: I18n.default_locale, role: 'visitor', feature_set: 'map_locate_feedback', flow: slug,
      source_spec: self.class.metadata[:file_path] }
  end

  def screenshot_narrative(title, bullet)
    {
      title:, audience: %w[visitor developer],
      journey_step: 'As a visitor, I can tell that the locate button is working and when it has found me.',
      callouts: [{ id: 'locate_button', title:, description: bullet }],
      accessibility_notes: 'State is also exposed through aria-busy and the polite map status message.'
    }
  end

  def capture_state(slug, title, bullet)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug, device: :both, metadata: screenshot_metadata(slug), narrative: screenshot_narrative(title, bullet),
            callouts: [{ id: 'locate_button', selector: '[data-geolocation-button]', title:, bullets: [bullet] }]
    ) do
      capybara_login_as_platform_manager
      visit better_together.communities_path(locale: I18n.default_locale)
      wait_for_leaflet_map
      yield
      page.execute_script("document.querySelector('[data-geolocation-button]').scrollIntoView({block: 'center'})")
    end
  end

  it 'captures the spinning globe while locating' do
    capture_state('map_locate_locating', 'Locating', 'A spinning globe shows the position is being found.') do
      script_browser_geolocation({ pending: true })
      click_button 'Geolocate Me'
      expect(page).to have_css('[data-geolocation-button] i.fa-spin')
    end
  end

  it 'captures the success state after the position is found' do
    capture_state('map_locate_located', 'Located',
                  'A check on a green button confirms the map is framed on the accuracy circle.') do
      script_browser_geolocation({ position: })
      click_button 'Geolocate Me'
      expect(page).to have_css('[data-geolocation-button].btn-success i.fa-circle-check')
    end
  end
end
