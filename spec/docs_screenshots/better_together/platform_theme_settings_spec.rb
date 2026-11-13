# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_theme_settings_spec.rb
#
# Documents the theme fields in the platform form Appearance tab, including the AA warning.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform theme settings', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
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

  def capture_theme(name, bullets, selector, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: { locale:, role: 'platform_manager', feature_set: 'platform_theme_settings',
                  flow: name, source_spec: self.class.metadata[:file_path] },
      callouts: [{ selector:, title: bullets.first, bullets: bullets.drop(1), position: 'below' }],
      &
    )
  end

  def open_appearance_tab
    capybara_login_as_platform_manager
    visit edit_platform_path(host_platform, locale:)
    find('#platform-appearance-tab').click
    expect(page).to have_css('#platform-appearance.show.active', wait: 10)
  end

  it 'captures the Foray palette with passing contrast' do
    result = capture_theme('platform_theme_foray_palette',
                           ['Contrast checks', 'Every pair passes AA.'], '#platform-theme-contrast') do
      open_appearance_tab
      find('#platform-theme-preset-foray').click
      expect(page).to have_css('#platform-theme-contrast-primary_text.text-success', wait: 5)
      find('#platform-theme-colors').scroll_to(:top)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_theme_foray_palette.png')
  end

  it 'captures a low contrast warning' do
    result = capture_theme('platform_theme_low_contrast',
                           ['AA warning', 'White on orange is 2.97:1.'], '#platform-theme-contrast-primary_text') do
      open_appearance_tab
      fill_in 'platform_theme_primary', with: '#ee722a'
      fill_in 'platform_theme_primary_text', with: '#ffffff'
      expect(page).to have_css('#platform-theme-contrast-primary_text.text-danger', wait: 5)
      find('#platform-theme-contrast').scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_theme_low_contrast.png')
  end
end
