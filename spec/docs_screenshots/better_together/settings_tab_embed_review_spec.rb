# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for full settings tab flows', :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
  end

  after do
    Current.platform = nil
  end

  def capture_settings_tab(slug:, tab_selector:)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: screenshot_metadata
    ) do
      open_settings_tab(tab_selector)
      yield
    end
  end

  it 'captures full settings page blocked people tab screenshots' do
    blocked_person = create(:better_together_person, name: 'Embedded Blocked Person')
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    create(:person_block, blocker: manager.person, blocked: blocked_person)

    slug = ENV.fetch('BLOCKED_PEOPLE_SLUG', 'release_0_11_0_settings_blocked_people')

    result = capture_settings_tab(
      slug:,
      tab_selector: '#blocked-people-tab'
    ) do
      expect(page).to have_text(I18n.t('better_together.settings.index.blocked_people.title'))
      expect(page).to have_text(blocked_person.name)
      expect(page).to have_link(I18n.t('better_together.person_blocks.index.block_person'))
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  it 'captures full settings page my data tab screenshots' do
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    export = manager.person.person_data_exports.create!(
      requested_at: Time.zone.parse('2026-04-02 12:00:00 UTC'),
      format: 'json'
    )
    BetterTogether::GeneratePersonDataExportJob.perform_now(export.id)

    slug = ENV.fetch('MY_DATA_SETTINGS_SLUG', 'release_0_11_0_settings_my_data_tab')

    result = capture_settings_tab(
      slug:,
      tab_selector: '#my-data-tab'
    ) do
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.exports.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.connections.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.connections.cards.person_links.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.exports.status_values.completed'))
      expect(page).to have_link(I18n.t('better_together.settings.index.my_data.exports.download'))
      expect(page).to have_link(I18n.t('better_together.settings.index.my_data.connections.cards.person_links.open_link'),
                                href: person_links_path(locale: I18n.default_locale))
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end

  it 'captures full settings page account tab screenshots with deletion UI' do
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    create(:better_together_person_deletion_request, person: manager.person)

    slug = ENV.fetch('ACCOUNT_DELETION_SLUG', 'release_0_11_0_settings_account_deletion')

    result = capture_settings_tab(
      slug:,
      tab_selector: '#account-tab'
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
