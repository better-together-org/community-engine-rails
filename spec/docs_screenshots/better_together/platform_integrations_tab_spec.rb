# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_integrations_tab_spec.rb
#
# Documents the Integrations tab of the platform form, desktop and mobile.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the platform Integrations tab', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :platform_settings,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  [false, true].each do |annotated|
    it "captures the integrations tab#{' annotated' if annotated}" do
      name = "platform_form_tab_integrations#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#platform-integrations-tab', title: 'Integrations tab',
                      bullets: ['Settings registered by extension gems, one set per platform.'], position: 'above' }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name,
        device: :both,
        metadata: {
          locale:, role: 'platform_manager', feature_set: 'platform_integrations',
          flow: 'platform_edit_integrations', source_spec: self.class.metadata[:file_path]
        },
        callouts:
      ) do
        capybara_login_as_platform_manager
        visit edit_platform_path(host_platform, locale:)
        find('#platform-integrations-tab').click
        expect(page).to have_css('#platform-integrations.show.active', wait: 10)
        find('#platform-integrations-tab').scroll_to(:center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end
end
