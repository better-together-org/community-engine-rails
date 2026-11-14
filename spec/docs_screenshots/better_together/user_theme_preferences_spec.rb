# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/user_theme_preferences_spec.rb
#
# Documents the Appearance controls in a person's settings (theme and colour mode with a live preview).

require 'rails_helper'

RSpec.describe 'Documentation screenshots for user theme preferences', # rubocop:disable RSpec/SpecFilePathSuffix
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

  after do
    Current.platform = nil
    host_platform.update!(allow_user_themes: true)
  end

  def capture_appearance(name, bullets, selector, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: { locale:, role: 'person', feature_set: 'user_theme_preferences',
                  flow: name, source_spec: self.class.metadata[:file_path] },
      callouts: [{ selector:, title: bullets.first, bullets: bullets.drop(1), position: 'below' }],
      &
    )
  end

  def open_appearance
    capybara_login_as_user
    visit settings_path(locale:)
    find('#preferences-tab').click
    expect(page).to have_css('#person-appearance-preferences', wait: 10)
    find('#person-appearance-preferences').scroll_to(:top)
  end

  it 'captures the theme and colour mode controls' do
    result = capture_appearance('user_theme_preferences_controls',
                                ['Appearance', 'Pick your own theme and colour mode.'], '#person-appearance-preferences') do
      open_appearance
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/user_theme_preferences_controls.png')
  end

  it 'captures a theme previewed in dark mode' do
    result = capture_appearance('user_theme_preferences_preview_dark',
                                ['Live preview', 'Each choice shows here before it saves.'], '#user-theme-preview') do
      open_appearance
      select 'Warm', from: 'person_theme'
      select 'Dark', from: 'person_color_mode'
      expect(page).to have_css('#user-theme-preview .bts-preview[data-bs-theme=dark]', wait: 5)
      find('#user-theme-preview').scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/user_theme_preferences_preview_dark.png')
  end

  it 'captures the settings when the platform allows only the colour mode' do
    host_platform.update!(allow_user_themes: false)
    result = capture_appearance('user_theme_preferences_themes_off',
                                ['Colour mode only', 'This platform uses one theme for everyone.'],
                                '#person-appearance-preferences') do
      open_appearance
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/user_theme_preferences_themes_off.png')
  end
end
