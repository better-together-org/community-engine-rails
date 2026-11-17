# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/theme_colour_modes_spec.rb
#
# A theme and a colour mode are chosen separately, so the header, footer, mobile bar, language menu and pill tabs
# must read correctly in every pairing. These captures show the pairings that used to clash: the warm theme and the
# dark theme, each in light mode.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for theme and colour mode pairings', # rubocop:disable RSpec/SpecFilePathSuffix
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
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'theme_colour_modes', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_pairing(theme_id, mode)
    host_platform.update!(theme: BetterTogether::PlatformThemeConfig.flat_theme(theme_id).merge('preset' => theme_id))
    capybara_login_as_platform_manager
    visit better_together.settings_path(locale: I18n.default_locale)
    expect(page).to have_css('#app-footer')
    page.execute_script(<<~JS)
      document.documentElement.setAttribute('data-bs-theme', '#{mode}');
      document.querySelector('#app-footer').scrollIntoView({ block: 'end' });
    JS
    sleep 0.4
  end

  %w[warm dark].each do |theme_id|
    %i[desktop mobile].each do |device|
      it "shows the #{theme_id} theme in light mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "theme_#{theme_id}_light_mode_#{device}", device:, metadata: metadata("theme_#{theme_id}_light_#{device}"),
                                                    callouts: [{ selector: '#app-footer', title: 'Footer',
                                                                 bullets: ['Uses the theme footer colours.'] }]
        ) { show_pairing(theme_id, 'light') }
      end

      it "captures the plain #{theme_id} theme in light mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "theme_#{theme_id}_light_mode_#{device}_plain", device:,
                                                          metadata: metadata("theme_#{theme_id}_light_#{device}_plain")
        ) { show_pairing(theme_id, 'light') }
      end
    end
  end
end
