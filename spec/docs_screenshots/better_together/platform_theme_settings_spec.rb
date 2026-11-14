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

  def pick_theme(id)
    names = { 'neutral' => 'Neutral light', 'warm' => 'Warm', 'cool' => 'Cool',
              'high_contrast' => 'High contrast', 'dark' => 'Dark' }
    find('#platform-theme-picker .ss-main').click
    find('.ss-content.ss-open-below .ss-option', text: names.fetch(id), exact_text: true).click
  end

  it 'captures the theme dropdown open' do
    result = capture_theme('platform_theme_dropdown', ['Theme picker', 'Choose one of five accessible themes.'],
                           '#platform-theme-picker') do
      open_appearance_tab
      find('#platform-theme-picker .ss-main').click
      expect(page).to have_css('.ss-content.ss-open-below .ss-option', wait: 5)
      find('#platform-theme-picker').scroll_to(:top)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_theme_dropdown.png')
  end

  %w[neutral warm cool high_contrast dark].each do |id|
    it "captures the #{id} theme previewed" do
      name = "platform_theme_preview_#{id}"
      result = capture_theme(name, ['Live preview', 'Nothing is saved until you save the platform.'],
                             '#platform-theme-preview') do
        open_appearance_tab
        pick_theme(id)
        expect(page).to have_css('#platform-theme-status', text: /Previewing/, wait: 5)
        find('#platform-theme-preview').scroll_to(:center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end

  it 'captures a low contrast warning' do
    result = capture_theme('platform_theme_low_contrast',
                           ['AA warning', 'White on orange is 2.97:1.'], '#platform-theme-contrast-primary_text-primary') do
      open_appearance_tab
      fill_in 'platform_theme_primary', with: '#ee722a'
      fill_in 'platform_theme_primary_text', with: '#ffffff'
      expect(page).to have_css('#platform-theme-contrast-primary_text-primary.text-danger', wait: 5)
      find('#platform-theme-contrast').scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_theme_low_contrast.png')
  end
end
