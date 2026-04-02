# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for person deletion review flow', :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures the account deletion entrypoint and optional my data flow evidence' do
    entry_slug = ENV.fetch('ENTRY_SLUG', 'person_deletion_entrypoint')
    expect_direct_delete_button = ENV['EXPECT_DIRECT_DELETE_BUTTON'] == '1'

    entry_result = BetterTogether::CapybaraScreenshotEngine.capture(
      entry_slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'person_deletion_review',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
      visit edit_user_registration_path(locale: I18n.default_locale, cancel: 1)

      expect(page).to have_text(I18n.t('devise.registrations.edit.cancel_my_account'))

      if expect_direct_delete_button
        expect(page).to have_button(I18n.t('devise.registrations.edit.cancel_my_account'))
      else
        expect(page).to have_link(I18n.t('better_together.settings.index.my_data.title'))
        expect(page).to have_no_button(I18n.t('devise.registrations.edit.cancel_my_account'))
      end
    end

    expect(entry_result[:desktop]).to end_with("docs/screenshots/desktop/#{entry_slug}.png")
    expect(entry_result[:mobile]).to end_with("docs/screenshots/mobile/#{entry_slug}.png")

    next unless ENV['CAPTURE_MY_DATA'] == '1'

    my_data_slug = ENV.fetch('MY_DATA_SLUG', 'person_deletion_my_data')
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    manager.person.person_deletion_requests.active.first ||
      manager.person.person_deletion_requests.create!(
        requested_at: Time.current,
        requested_reason: 'Documentation screenshot request'
      )

    my_data_result = BetterTogether::CapybaraScreenshotEngine.capture(
      my_data_slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'person_deletion_review',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
      visit settings_my_data_path(locale: I18n.default_locale)

      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.deletion.title'))
      expect(page).to have_button(I18n.t('better_together.settings.index.my_data.deletion.cancel'))
    end

    expect(my_data_result[:desktop]).to end_with("docs/screenshots/desktop/#{my_data_slug}.png")
    expect(my_data_result[:mobile]).to end_with("docs/screenshots/mobile/#{my_data_slug}.png")
  end
end
