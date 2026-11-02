# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/settlement_weather_spec.rb'
#
# Assets land in docs/screenshots/{desktop,mobile}/settlement_weather_*.{png,json,narrative.yml}

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the settlement weather tab',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               :weather_seed,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:settlement) { create(:geography_settlement, name: 'Corner Brook') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    seed_weather_panel(create(:weather_location, settlement: settlement))
  end

  after { Current.platform = nil }

  def capture(name, target, callouts) # rubocop:disable Metrics/AbcSize
    narrative = { title: "Settlement weather: #{name}", audience: %w[end_user],
                  journey_step: 'As a visitor, I can see current conditions, the forecast and recent weather.',
                  callouts: callouts.map { |c| { id: c[:id], title: c[:title], description: c[:bullets].first } },
                  accessibility_notes: 'Charts have a text alternative and a data table with the same values.' }
    metadata = { locale: I18n.default_locale, role: 'visitor', feature_set: 'weather', flow: name,
                 source_spec: self.class.metadata[:file_path] }

    BetterTogether::CapybaraScreenshotEngine.capture("settlement_weather_#{name}", device: :both, metadata:, narrative:,
                                                                                   callouts:) do
      visit "/#{I18n.default_locale}/g/settlements/#{settlement.slug}"
      find('#weather-tab').click
      expect(page).to have_css(target, wait: 15)
      expect(page).to have_css('#weather-chart-temperature', visible: :all, wait: 10)
      page.execute_script("document.querySelector('#{target}').scrollIntoView({block: 'start'})")
    end
  end

  it 'captures current conditions' do # rubocop:disable RSpec/NoExpectationExample
    capture('current', '#weather-current',
            [{ id: 'current', selector: '#weather-current', title: 'Current conditions',
               bullets: ['From the latest stored observation, with its time.'] }])
  end

  it 'captures the 14 day history charts' do # rubocop:disable RSpec/NoExpectationExample
    capture('history', '#weather-history',
            [{ id: 'charts', selector: '#weather-history-data', title: 'Same values as a table',
               bullets: ['Every chart has a text alternative.'] }])
  end
end
