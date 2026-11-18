# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/header_menu_theme_spec.rb
#
# Header menus under a themed, dark header (the Better Together host app's header rules applied): the account menu
# with its Host submenu in light and dark mode, and the language menu opening above a "saved" flash alert.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for themed header menus', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :no_auth,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false,
                       theme: BetterTogether::PlatformThemeConfig.flat_theme('cool').merge('preset' => 'cool'))
    end
  end
  let(:host_header_css) do
    <<~CSS
      #main-nav { position: sticky; top: 0; z-index: 1000; background: var(--bts-navbar-bg, #b1e3cc); }
      #main-nav a:not(.dropdown-item) { color: var(--bts-navbar-link, #222); }
      #main-nav .dropdown-menu { background: var(--bts-navbar-bg, #b1e3cc); }
      [data-bs-theme='dark'] #main-nav .dropdown-menu { background: var(--bts-navbar-bg, #133526); }
    CSS
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
  end

  after do
    host_platform.update!(theme: {})
    Current.platform = nil
  end

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'header_menu_theme', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_settings(mode)
    capybara_login_as_platform_manager
    visit better_together.settings_path(locale: I18n.default_locale)
    page.execute_script(<<~JS, host_header_css, mode)
      const style = document.createElement('style'); style.textContent = arguments[0];
      document.querySelector('#platform-theme-style').before(style);
      document.documentElement.setAttribute('data-bs-theme', arguments[1]);
      window.__btDocsScreenshotHidden = true;
    JS
  end

  def open_account_menu(mode)
    open_settings(mode)
    find('#userNavbarDropdownMenuLink').click
    find('#host-nav-item .dropdown-toggle').click
    expect(page).to have_css('#host-nav-item .dropdown-menu.show')
    find('#user-nav .dropdown-item[data-identifier="settings"]').hover
    sleep 0.3
  end

  def open_language_over_flash
    open_settings('light')
    page.execute_script(<<~JS)
      document.querySelector('#col-flash-message').innerHTML =
        '<div class="alert alert-success text-center" role="alert" id="docs-flash">Preference saved successfully</div>';
    JS
    find('#localeDropdownMenuLink').click
    expect(page).to have_css('#locale-switcher .dropdown-menu.show')
    find('#locale-switcher .dropdown-item:not(.active)', match: :first).hover
    sleep 0.3
  end

  %w[light dark].each do |mode|
    %i[desktop mobile].each do |device|
      it "shows the account and Host menus in #{mode} mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "header_menu_theme_account_#{mode}_#{device}", device:,
                                                         metadata: metadata("account_#{mode}_#{device}"),
                                                         callouts: [{ selector: '#host-nav-item', title: 'Host',
                                                                      bullets: ['Aligned with the other items.',
                                                                                'Readable on the page surface.'] }]
        ) { open_account_menu(mode) }
      end

      it "captures the plain account and Host menus in #{mode} mode on #{device}" do # rubocop:disable RSpec/NoExpectationExample
        BetterTogether::CapybaraScreenshotEngine.capture(
          "header_menu_theme_account_#{mode}_#{device}_plain", device:,
                                                               metadata: metadata("account_#{mode}_#{device}_plain")
        ) { open_account_menu(mode) }
      end
    end
  end

  %i[desktop mobile].each do |device|
    it "shows the language menu above a flash alert on #{device}" do # rubocop:disable RSpec/NoExpectationExample
      BetterTogether::CapybaraScreenshotEngine.capture(
        "header_menu_theme_language_flash_#{device}", device:, metadata: metadata("language_flash_#{device}"),
                                                      callouts: [{ selector: '#locale-switcher .dropdown-menu',
                                                                   title: 'Language',
                                                                   bullets: ['Opens above the saved alert.',
                                                                             'Hover and current item visible.'] }]
      ) { open_language_over_flash }
    end

    it "captures the plain language menu above a flash alert on #{device}" do # rubocop:disable RSpec/NoExpectationExample
      BetterTogether::CapybaraScreenshotEngine.capture(
        "header_menu_theme_language_flash_#{device}_plain", device:,
                                                            metadata: metadata("language_flash_#{device}_plain")
      ) { open_language_over_flash }
    end
  end
end
