# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/color_mode_toggle_spec.rb
#
# The header shows one button for the appearance in use (sun for light, moon for dark). Auto follows the device until
# the first click, and Preferences can set Auto, Light or Dark again.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the colour mode toggle', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'color_mode_toggle', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_page(mode)
    capybara_login_as_platform_manager
    visit better_together.settings_path(locale: I18n.default_locale)
    page.execute_script("localStorage.removeItem('bts-color-mode')")
    find('#color-mode-button').click if mode == 'dark'
    expect(page).to have_css("html[data-bs-theme=#{mode}] #color-mode-button", count: 1)
    sleep 0.3
  end

  %w[light dark].each do |mode|
    %i[desktop mobile].each do |device|
      it "shows the single toggle in #{mode} mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "color_mode_toggle_#{mode}_#{device}", device:, metadata: metadata("color_mode_toggle_#{mode}_#{device}"),
                                                 callouts: [{ selector: '#color-mode-toggle', title: 'Colour mode',
                                                              bullets: ['One button, current appearance shown.'] }]
        ) { open_page(mode) }
      end

      it "captures the plain toggle in #{mode} mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "color_mode_toggle_#{mode}_#{device}_plain", device:,
                                                       metadata: metadata("color_mode_toggle_#{mode}_#{device}_plain")
        ) { open_page(mode) }
      end
    end
  end
end
