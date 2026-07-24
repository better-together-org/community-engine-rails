# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/event_map_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/event_map_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the Locatable event map',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'event_map',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def geocode!(locatable_location)
    create(:geography_geospatial_space, geospatial: locatable_location.location, space: create(:geography_space))
  end

  it 'captures the single-event map on the event show page' do
    event = create(:better_together_event, :with_address_location, platform: host_platform,
                                                                   creator: manager.person,
                                                                   name: 'Community Meetup')
    geocode!(event.location)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_map_show',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_map_show', role: 'event_organizer'),
      callouts: [
        {
          id: 'event_map',
          selector: '.event-map',
          title: 'Location map',
          bullets: [
            'Renders automatically once the event has a geocoded Address, Building, Settlement, or Region.',
            'Powered by the reusable Locatable::One#leaflet_points mechanism — no per-event configuration.'
          ]
        }
      ],
      narrative: {
        title: 'Event Show — Location Map',
        audience: %w[event_organizer community_organizer developer],
        journey_step: 'As an event organizer, I see exactly where the event is on an interactive map, ' \
                      'not just as a text address.',
        callouts: [
          {
            id: 'event_map',
            title: 'Leaflet map for the assigned location',
            description: 'New in this PR: BetterTogether::Geography::Locatable::One now includes ' \
                         'Mappable and provides leaflet_points/spaces, so any Locatable::One-including ' \
                         'model (Event today; Joatu Offer/Request once they adopt the same concern) gets ' \
                         'this map for free — no per-model map code required.'
          }
        ],
        accessibility_notes: 'The map controls (layer toggle, geolocation) are real buttons with visible ' \
                             'focus state and accessible labels.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.event_path(event, locale: I18n.default_locale)

      expect(page).to have_css('.event-map [data-controller="better_together--map"]')
    end
  end

  it 'captures the aggregate map on the events index page' do
    event = create(:better_together_event, :with_address_location, platform: host_platform,
                                                                   creator: manager.person,
                                                                   name: 'Neighbourhood Cleanup')
    geocode!(event.location)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_map_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_map_index', role: 'community_organizer'),
      callouts: [
        {
          id: 'events_map',
          selector: '.events-map',
          title: 'All events with a location',
          bullets: [
            'Aggregates every event with a geocoded location onto one map (BetterTogether::Geography::EventCollectionMap).',
            'Mirrors the existing communities index map — same shared _map.html.erb partial and Stimulus controller.'
          ]
        }
      ],
      narrative: {
        title: 'Events Index — Aggregate Location Map',
        audience: %w[community_organizer platform_organizer developer],
        journey_step: 'As a community organizer browsing events, I see at a glance where events are ' \
                      'happening across the platform, not just as a list.',
        callouts: [
          {
            id: 'events_map',
            title: 'EventCollectionMap',
            description: 'New STI subtype: BetterTogether::Geography::EventCollectionMap < LocatableMap. ' \
                         'It queries every event with an assigned location and flattens their individual ' \
                         'leaflet_points into one collection, the same pattern already used by ' \
                         'CommunityCollectionMap on the communities index.'
          }
        ],
        accessibility_notes: 'Marker popups use the event name as visible link text, satisfying link- ' \
                             'purpose-in-context for screen reader users.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale: I18n.default_locale)

      expect(page).to have_css('.events-map [data-controller="better_together--map"]')
    end
  end
end
