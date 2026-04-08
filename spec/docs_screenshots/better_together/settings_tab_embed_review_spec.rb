# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for settings tab embeds', :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
  end

  after do
    Current.platform = nil
  end

  def capture_settings_tab(slug:, tab_selector:, frame_selector:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: screenshot_metadata
    ) do
      open_settings_tab(tab_selector)
      within(frame_selector, &)
    end
  end

  it 'captures embedded blocked people tab screenshots' do
    blocked_person = create(:better_together_person, name: 'Embedded Blocked Person')
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    create(:person_block, blocker: manager.person, blocked: blocked_person)

    slug = ENV.fetch('EMBEDDED_BLOCKED_PEOPLE_SLUG', 'settings_blocked_people_embedded')

    result = capture_settings_tab(
      slug:,
      tab_selector: '#blocked-people-tab',
      frame_selector: 'turbo-frame#blocked-people-settings'
    ) do
      expect(page).to have_text(blocked_person.name)
      expect(page).to have_link(I18n.t('better_together.person_blocks.index.block_person'))
      expect(page).to have_no_css('h2', text: I18n.t('better_together.person_blocks.index.title'))
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  it 'captures embedded account tab screenshots with deletion UI' do
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    create(:better_together_person_deletion_request, person: manager.person)

    slug = ENV.fetch('EMBEDDED_ACCOUNT_DELETION_SLUG', 'settings_account_deletion_embedded')

    result = capture_settings_tab(
      slug:,
      tab_selector: '#account-tab',
      frame_selector: 'turbo-frame#account-settings'
    ) do
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.deletion.title'))
      expect(page).to have_button(I18n.t('better_together.settings.index.my_data.deletion.submit'))
      expect(page).to have_button(I18n.t('better_together.settings.index.my_data.deletion.cancel'))
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  private

  def screenshot_metadata
    {
      locale: I18n.default_locale,
      role: 'platform_manager',
      feature_set: 'settings_embed_review',
      source_spec: self.class.metadata[:file_path]
    }
  end

  def open_settings_tab(tab_selector)
    capybara_login_as_platform_manager
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
    visit settings_path(locale: I18n.default_locale)
    find(tab_selector, wait: 10).click
    expect(page).to have_css("#{tab_selector}.active", wait: 10)
  end
end
