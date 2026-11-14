# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for 0.11.0 setup wizard and bootstrap guard',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:restore_ids) { {} }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = nil
    # Platforms, communities and wizards are in ESSENTIAL_TABLES, so these changes outlive the example.
    # Remember what to restore, otherwise every later example runs without a host platform.
    restore_ids[:platforms] = BetterTogether::Platform.where(host: true).pluck(:id)
    restore_ids[:communities] = BetterTogether::Community.where(host: true).pluck(:id)
    BetterTogether::Platform.where(host: true).update_all(host: false)
    BetterTogether::Community.where(host: true).update_all(host: false)
    reset_host_setup_wizard!
  end

  after do
    restore_host_state!
    Current.platform = nil
  end

  it 'captures the setup wizard platform details step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'release_0_11_0_setup_wizard_platform_details',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'setup_wizard',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      visit new_user_session_path(locale: I18n.default_locale)

      expect(page).to have_current_path(setup_wizard_step_platform_details_path(locale: I18n.default_locale), wait: 10)
      expect(page).to have_field('platform[name]')
      expect(page).to have_field('platform[host_url]')

      page.execute_script(
        'arguments[0].scrollIntoView({block: "start", behavior: "instant"})',
        find_field('platform[name]').native
      )
    end
  end

  it 'captures the completed setup wizard re-entry guard' do
    # A completed setup means a host platform exists again.
    restore_host_state!
    BetterTogether::Wizard.find_by!(identifier: 'host_setup').mark_completed

    BetterTogether::CapybaraScreenshotEngine.capture(
      'release_0_11_0_setup_wizard_completed_redirect',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'setup_wizard',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      visit better_together.setup_wizard_path(locale: I18n.default_locale)

      # A visitor who is not signed in is sent to the sign-in page with the "already completed" notice.
      expect(page).to have_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
      expect(page).to have_css('.alert, .notice', wait: 10)

      page.execute_script(
        'arguments[0].scrollIntoView({block: "start", behavior: "instant"})',
        find('.alert, .notice', wait: 10).native
      )
    end
  end

  private

  def restore_host_state!
    BetterTogether::Platform.where(id: restore_ids[:platforms]).update_all(host: true) if restore_ids[:platforms].present?
    BetterTogether::Community.where(id: restore_ids[:communities]).update_all(host: true) if restore_ids[:communities].present?
    BetterTogether::Wizard.find_by(identifier: 'host_setup')&.mark_completed
  end

  def reset_host_setup_wizard!
    wizard = BetterTogether::Wizard.find_by!(identifier: 'host_setup')
    wizard.wizard_steps.delete_all
    wizard.update!(
      current_completions: 0,
      first_completed_at: nil,
      last_completed_at: nil
    )
  end
end
