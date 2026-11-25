# frozen_string_literal: true

# Capture command (run from repo root, one worker):
#   RUN_DOCS_SCREENSHOTS=1 WORKERS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/host_dashboard_managed_steward_spec.rb
#
# Documents the dashboard a managed platform's steward lands on (HPS-1): it opens on their own domain and
# counts only their platform's records.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the managed steward dashboard', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:setup) { managed_platform_setup(managed_attributes: { host_url: managed_host_url }) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    use_managed_origin(setup)
    create_list(:better_together_page, 3, platform: setup.managed_platform)
    create_list(:better_together_page, 5, platform: setup.operator_platform)
  end

  after { reset_managed_origin }

  it 'captures the dashboard overview as a managed platform steward' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'host_dashboard_managed_steward_overview',
      device: :both,
      metadata: {
        locale: I18n.default_locale, role: 'managed_platform_steward', feature_set: 'host_dashboard',
        flow: 'managed_steward_dashboard', source_spec: self.class.metadata[:file_path]
      },
      callouts: [
        {
          id: 'platform_resources',
          selector: '#host-dashboard-page-card',
          title: 'Only this platform',
          bullets: ['Pages and platforms count only this platform: 3 pages, 1 platform, not the operator or others.']
        }
      ],
      narrative: {
        journey_step: 'As the steward of a managed platform, I sign in on my own domain and land on a dashboard ' \
                      'that describes only my platform.',
        callouts: [
          { id: 'platform_resources', title: 'Only this platform',
            description: 'The dashboard authorizes against the platform being viewed and scopes every count to it.' }
        ],
        accessibility_notes: 'Sections have stable ids and visible headings.'
      }
    ) do
      sign_in_on_managed_platform(setup.managed_steward)
      visit managed_url(better_together.host_dashboard_path(locale: I18n.default_locale))
      expect(page).to have_css('#host-dashboard-page-card')
      scroll_to(find('#host-dashboard-page-card'), align: :top)
    end
  end
end
