# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/event_series_spec.rb'
RSpec.describe 'Documentation screenshots for event series', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:series) do
    create(:event, series: true, starts_at: nil, ends_at: nil, privacy: 'public', platform: host_platform,
                   creator: manager.person, name: 'A Tribute to Fleetwood Mac')
  end
  let(:friday) { add_session('A Tribute to Fleetwood Mac', 3.days.from_now) }
  let(:saturday) { add_session('Fleetwood Mac Tribute: Matinee', 4.days.from_now) }

  def add_session(name, start)
    create(:event, starts_at: start, ends_at: start + 2.hours, privacy: 'public', name:, platform: host_platform,
                   creator: manager.person, session_of: series.identifier,
                   registration_url: 'https://tickets.example.test/night')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    [friday, saturday]
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'event_series', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def narrative(title, step, callouts)
    { title:, audience: %w[community_member developer], journey_step: step,
      callouts: callouts.map { |id, text| { id:, title: id.tr('_', ' ').capitalize, description: text } },
      accessibility_notes: 'Links carry their text; the panel is a labelled fieldset.' }
  end

  it 'captures the events list with series mentions' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_series_list', device: :both, metadata: metadata('list'),
                           callouts: [{ id: 'mention', selector: "#series_mention_event_#{friday.id}",
                                        title: 'Series mention', bullets: ['A session says which series it is part of.'] }],
                           narrative: narrative('Events list', 'As a visitor, I see that dates belong to a run.',
                                                'mention' => 'The series itself is not listed.')
    ) do
      capybara_login_as_platform_manager
      visit better_together.events_path(locale:)
      find("#series_mention_event_#{friday.id}").scroll_to(:center)
      expect(page).to have_css("#series_mention_event_#{friday.id}")
    end
  end

  it 'captures the plain events list' do
    BetterTogether::CapybaraScreenshotEngine.capture('event_series_list_plain', device: :both,
                                                                                metadata: metadata('list_plain')) do
      visit better_together.events_path(locale:)
      find("#series_mention_event_#{friday.id}").scroll_to(:center)
      expect(page).to have_css("#series_mention_event_#{friday.id}")
    end
  end

  it 'captures the series page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_series_show', device: :both, metadata: metadata('series'),
                           callouts: [{ id: 'sessions', selector: "#sessions_event_#{series.id}", title: 'Dates',
                                        bullets: ['Each date is a card linking to its own page.'] }],
                           narrative: narrative('Series page', 'As a visitor, I see every date of a run.',
                                                'sessions' => 'No RSVP on the series; each date has its own.')
    ) do
      visit better_together.event_path(series, locale:)
      find("#sessions_event_#{series.id}").scroll_to(:center)
      expect(page).to have_css("#sessions_event_#{series.id} .event-card", minimum: 2)
    end
  end

  it 'captures the plain series page' do
    BetterTogether::CapybaraScreenshotEngine.capture('event_series_show_plain', device: :both,
                                                                                metadata: metadata('series_plain')) do
      visit better_together.event_path(series, locale:)
      find("#sessions_event_#{series.id}").scroll_to(:center)
      expect(page).to have_css("#sessions_event_#{series.id} .event-card", minimum: 2)
    end
  end

  it 'captures a session page' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_series_session', device: :both, metadata: metadata('session'),
                              callouts: [{ id: 'banner', selector: "#series_banner_event_#{saturday.id}",
                                           title: 'Series banner', bullets: ['Links back to the series.'] }],
                              narrative: narrative('Session page', 'As a visitor, I find the rest of the run.',
                                                   'banner' => 'Names the series only when the names differ.')
    ) do
      visit better_together.event_path(saturday, locale:)
      expect(page).to have_css("#series_banner_event_#{saturday.id}")
    end
  end

  it 'captures the plain session page' do
    BetterTogether::CapybaraScreenshotEngine.capture('event_series_session_plain', device: :both,
                                                                                   metadata: metadata('session_plain')) do
      visit better_together.event_path(saturday, locale:)
      expect(page).to have_css("#series_banner_event_#{saturday.id}")
    end
  end

  it 'captures the cancel and delete panel' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'event_series_disposition', device: :both, metadata: metadata('disposition'),
                                  callouts: [{ id: 'disposition', selector: "#disposition_event_#{series.id}",
                                               title: 'Choose for the dates',
                                               bullets: ['Nothing is preselected.'] }],
                                  narrative: narrative('Cancel or delete a series', 'As an organizer, I decide what happens to the dates.',
                                                       'disposition' => 'Cancel, delete or keep the dates as events.')
    ) do
      capybara_login_as_platform_manager
      visit better_together.event_path(series, locale:)
      find("button[data-bs-target='#disposition_panel_event_#{series.id}']").click
      expect(page).to have_css("#disposition_panel_event_#{series.id}.show")
      find("#disposition_event_#{series.id}").scroll_to(:center)
    end
  end

  it 'captures the plain cancel and delete panel' do
    BetterTogether::CapybaraScreenshotEngine.capture('event_series_disposition_plain', device: :both,
                                                                                       metadata: metadata('disposition_plain')) do
      capybara_login_as_platform_manager
      visit better_together.event_path(series, locale:)
      find("button[data-bs-target='#disposition_panel_event_#{series.id}']").click
      expect(page).to have_css("#disposition_panel_event_#{series.id}.show")
      find("#disposition_event_#{series.id}").scroll_to(:center)
    end
  end
end
