# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/settings_usage_tab_spec.rb'
#
# Documents the settings Usage tab rendering its content inside the lazy turbo frame.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the settings usage tab', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let!(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  [false, true].each do |annotated|
    it "captures the usage tab#{' annotated' if annotated}" do
      name = "settings_usage_tab#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#usage-settings', title: 'Usage content', position: 'below',
                      bullets: ['Loads into the tab through its turbo frame.',
                                'No longer shows "Content missing".'] }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name, device: :both,
              metadata: { locale:, role: 'user', feature_set: 'quotas', flow: 'settings_usage_tab',
                          source_spec: self.class.metadata[:file_path] },
              callouts:
      ) do
        find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
        capybara_login_as_user
        visit better_together.settings_path(locale:)
        find('#usage-tab').click
        expect(page).to have_css('#usage-settings-none', visible: :visible, wait: 10)
        find('#usage-settings').scroll_to(:center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
      expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{name}.png")
    end
  end
end
