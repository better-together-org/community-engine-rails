# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/community_show_tabs_spec.rb'
RSpec.describe 'Documentation screenshots for the community page tabs', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:community) do
    create(:community, name: 'Harbour Arts Collective', privacy: 'public', creator: manager.person,
                       description: 'A volunteer collective running the harbour arts programme.')
  end
  let(:address) { create(:address) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:geography_geospatial_space, geospatial: address,
                                        space: create(:geography_space, latitude: 48.95, longitude: -57.95))
    community.create_location!(location: address, name: 'Harbour Hall')
    community.update!(contact_spec: { email_addresses: [{ email: 'hello@harbour.example', label: 'General' }],
                                      phone_numbers: [{ number: '709-555-0100', label: 'Box office' }] }.to_json)
    2.times do |i|
      event = create(:event, platform: host_platform, creator: manager.person, name: "Harbour Arts Night #{i + 1}",
                             starts_at: (i + 2).days.from_now, ends_at: (i + 2).days.from_now + 2.hours)
      event.event_hosts.destroy_all
      event.event_hosts.create!(host: community)
    end
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'community_show_tabs', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_community
    capybara_login_as_platform_manager
    visit better_together.community_path(locale:, id: community.slug)
    expect(page).to have_css('#community-tabbed-section')
  end

  it 'captures the about tab with the map beside the tabs' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_tabs_about', device: :both, metadata: metadata('about'),
                                   callouts: [
                                     { id: 'tabs', selector: '#communityTabs', title: 'Tabs',
                                       bullets: ['Driven by the tabs controller; Contact has its own tab.'] },
                                     { id: 'map', selector: '#community-map', title: 'Map',
                                       bullets: ['Beside the tabs; shows the place the community is located at.'] }
                                   ],
                                   narrative: {
                                     title: 'Community page, About tab',
                                     audience: %w[community_member developer],
                                     journey_step: 'As a visitor, I read about a community and see where it is.',
                                     callouts: [
                                       { id: 'tabs', title: 'Tabs', description: 'Hash links select a tab without scrolling.' },
                                       { id: 'map', title: 'Map', description: 'Falls back to the located place.' }
                                     ],
                                     accessibility_notes: 'Tabs use role=tablist, aria-controls and aria-labelledby pairs.'
                                   }
    ) do
      visit_community
      expect(page).to have_css('#community-map')
    end
  end

  it 'captures the plain about tab' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_tabs_about_plain', device: :both, metadata: metadata('about_plain')
    ) do
      visit_community
      expect(page).to have_css('#community-map')
    end
  end

  it 'captures the contact tab' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_tabs_contact', device: :both, metadata: metadata('contact'),
                                     callouts: [
                                       { id: 'contact', selector: '#contact', title: 'Contact',
                                         bullets: ['Phone and email in their own tab.'] }
                                     ],
                                     narrative: {
                                       title: 'Community page, Contact tab',
                                       audience: %w[community_member developer],
                                       journey_step: 'As a visitor, I find how to contact a community.',
                                       callouts: [{ id: 'contact', title: 'Contact', description: 'Public details only.' }],
                                       accessibility_notes: 'The pane is labelled by its tab.'
                                     }
    ) do
      visit_community
      find('#contact-tab').click
      expect(page).to have_css('#contact.active', text: 'hello@harbour.example')
    end
  end

  it 'captures the events tab with the embedded index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'community_show_tabs_events', device: :both, metadata: metadata('events'),
                                    callouts: [
                                      { id: 'events', selector: '#events', title: 'Events',
                                        bullets: ['The events index, scoped to the community, in a lazy frame.'] }
                                    ],
                                    narrative: {
                                      title: 'Community page, Events tab',
                                      audience: %w[community_member developer],
                                      journey_step: 'As a visitor, I see the events a community hosts.',
                                      callouts: [{ id: 'events', title: 'Events', description: 'Loaded on first view.' }],
                                      accessibility_notes: 'The frame heading is an h2 under the page h1.'
                                    }
    ) do
      visit_community
      find('#events-tab').click
      expect(page).to have_css('#events .event-card', minimum: 2)
    end
  end
end
