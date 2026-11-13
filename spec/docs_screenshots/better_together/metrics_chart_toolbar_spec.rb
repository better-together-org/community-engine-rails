# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/metrics_chart_toolbar_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/metrics_chart_toolbar_spec.rb.
RSpec.describe 'Documentation screenshots for the metrics chart export toolbar', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    configure_host_platform
  end

  it 'captures the export button above a chart' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'metrics_chart_toolbar', device: :both,
                               metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'metrics_reports',
                                           flow: 'metrics_chart_toolbar', source_spec: self.class.metadata[:file_path] },
                               callouts: [{ id: 'export', selector: '#page-views-chart-export', title: 'Export a chart',
                                            avoid_container_selector: 'main',
                                            bullets: ['Download this chart as PNG, JPG or CSV.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/host/metrics/reports"
      expect(page).to have_css('#page-views-chart-export')
      scroll_to(find('#page-views-chart-export'), align: :center)
    end
  end
end
