# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/weather_management_spec.rb'
#
# Assets land in docs/screenshots/{desktop,mobile}/weather_management_*.{png,json,narrative.yml}

require 'rails_helper'
require 'rake'

RSpec.describe 'Documentation screenshots for host weather management',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               :weather_stewards,
               retry: 0,
               type: :feature do
  let(:locale) { I18n.default_locale }
  let(:steward) { weather_host_steward }
  let(:eccc) { create(:weather_source, identifier: 'environment-canada-nl') }
  let(:backup) { create(:weather_source, identifier: 'backup-feed', enabled: false) }

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    seed_host_nav
    seed_sources
  end

  after { Current.platform = nil }

  def seed_host_nav
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/seed_rbac_and_navigation.rake').to_s
    Rake::Task.define_task(:environment)
    Rake::Task['better_together:seed:rbac_and_navigation'].invoke
  end

  def seed_sources
    { 'Corner Brook' => 10.minutes.ago, 'Deer Lake' => 12.minutes.ago, 'Pasadena' => 3.hours.ago }
      .each do |name, refreshed|
        settlement = create(:geography_settlement, :without_country, :without_state, name:)
        create(:weather_location, source: eccc, settlement:, last_refreshed_at: refreshed)
      end
    create(:weather_location, source: backup, last_refreshed_at: 2.days.ago,
                              settlement: create(:geography_settlement, :without_country, :without_state,
                                                 name: 'Steady Brook'))
  end

  def capture(name, target, callout, &) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    narrative = { title: "Weather management: #{name.tr('_', ' ')}", audience: %w[platform_organizers],
                  journey_step: 'As a host steward, I can switch weather, its sources and locations on or off.',
                  callouts: [{ id: name, title: callout[:title], description: callout[:bullets].first }],
                  accessibility_notes: 'Every switch goes through a confirm page that states its effect in text.' }
    metadata = { locale:, role: 'host_steward', feature_set: 'weather_management', flow: name,
                 source_spec: self.class.metadata[:file_path] }

    # Annotated (callout drawn on the image) and plain (no callout) variants of the same view.
    { '' => [callout.merge(id: name, selector: target)], '_plain' => [] }.each do |suffix, callouts|
      BetterTogether::CapybaraScreenshotEngine.capture(
        "weather_management_#{name}#{suffix}", device: :both, metadata:, narrative:, callouts:
      ) do
        login_as(steward, scope: :user)
        instance_exec(&)
        expect(page).to have_css(target, wait: 15)
        scroll_to(find(target), align: :center)
      end
    end
  end

  it 'captures the weather tab with sources' do # rubocop:disable RSpec/NoExpectationExample
    capture('sources', '#weather-sources-table',
            { title: 'Sources at a glance',
              bullets: ['Enabled and total locations, last refresh, last successful refresh and a stale flag.'] }) do
      visit better_together.host_dashboard_weather_path(locale:)
    end
  end

  it 'captures the locations of a source' do # rubocop:disable RSpec/NoExpectationExample
    capture('locations', '#weather-locations-table',
            { title: 'Locations of one source',
              bullets: ['Each location can be switched on or off; creation stays with host seeds.'] }) do
      visit better_together.host_dashboard_weather_source_path(eccc, locale:)
    end
  end

  it 'captures the confirm step for turning weather off' do # rubocop:disable RSpec/NoExpectationExample
    capture('confirm_off', '#weather-confirm-effect',
            { title: 'Confirm with the effect stated',
              bullets: ['Turning weather off stops every job and hides weather on every platform on this host.'] }) do
      visit better_together.confirm_host_dashboard_weather_feature_path(enabled: false, locale:)
    end
  end

  it 'captures the change history after a source is disabled' do # rubocop:disable RSpec/NoExpectationExample
    capture('history', '#weather-audit-table',
            { title: 'Who changed what, and when',
              bullets: ['Each change lists the steward, the source or location, and the value before and after.'] }) do
      visit better_together.confirm_host_dashboard_weather_source_path(eccc, enabled: false, locale:)
      click_button 'weather-confirm-btn'
      expect(page).to have_css('#weather-audit-table .weather-audit-row', wait: 15)
    end
  end

  it 'captures the switch locked by the server setting' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether.weather_enabled = false
    capture('env_kill_switch', '#weather-env-kill-switch-notice',
            { title: 'Server setting wins',
              bullets: ['The server environment setting turns weather off and locks the switch.'] }) do
      visit better_together.host_dashboard_weather_path(locale:)
    end
  end
end
