# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

RSpec.describe 'Documentation screenshots for person deletion review flow', :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    ensure_platform_manager!
  end

  after do
    Current.platform = nil
  end

  def ensure_pending_deletion_request!
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    manager.person.person_deletion_requests.active.first ||
      manager.person.person_deletion_requests.create!(
        requested_at: Time.current,
        requested_reason: 'Documentation screenshot request'
      )
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def ensure_platform_manager!
    manager = BetterTogether::User.find_or_initialize_by(email: 'manager@example.test')
    manager.password = 'SecureTest123!@#' if manager.new_record?
    manager.confirmed_at ||= Time.zone.now
    manager.confirmation_sent_at ||= Time.zone.now

    unless manager.person
      manager.build_person(name: 'Platform Steward', identifier: 'manager-example-test')
    end

    manager.save! if manager.new_record? || manager.changed? || manager.person&.changed?
    manager
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    BetterTogether::User.find_by!(email: 'manager@example.test').tap do |user|
      user.update_columns(confirmed_at: Time.zone.now, confirmation_sent_at: Time.zone.now) unless user.confirmed?
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def reset_personal_export_artifacts!(person)
    person.person_data_exports.destroy_all
    BetterTogether::Seed.personal_exports_for(person).destroy_all
  end

  def create_personal_export!(person)
    export = person.person_data_exports.create!(
      requested_at: Time.zone.parse('2026-04-02 12:00:00 UTC'),
      format: 'json'
    )
    BetterTogether::GeneratePersonDataExportJob.perform_now(export.id)
    export.reload
  end

  def ensure_seed_yaml_attached!(seed)
    return seed if seed.yaml_file.attached?

    seed.yaml_file.attach(
      io: StringIO.new(YAML.dump(seed.payload.deep_stringify_keys)),
      filename: "person-seed-#{seed.id}.yml",
      content_type: 'application/yaml'
    )
    seed
  end

  def ensure_personal_export_artifacts!
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    person = manager.person

    reset_personal_export_artifacts!(person)
    export = create_personal_export!(person)
    seed = ensure_seed_yaml_attached!(BetterTogether::Seed.personal_exports_for(person).latest_first.first!)

    {
      manager: manager,
      person: person,
      export: export,
      seed: seed
    }
  end

  def scroll_to_heading!(text)
    heading = find('h2', text:, wait: 10)
    page.execute_script('arguments[0].scrollIntoView({ block: "start", behavior: "instant" });', heading.native)
    expect(heading).to be_visible
  end

  it 'captures the account deletion entrypoint and optional my data flow evidence' do
    entry_slug = ENV.fetch('ENTRY_SLUG', 'person_deletion_entrypoint')
    expect_direct_delete_button = ENV['EXPECT_DIRECT_DELETE_BUTTON'] == '1'
    ensure_pending_deletion_request! if expect_direct_delete_button

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
      ensure_platform_manager!
      capybara_login_as_platform_manager
      expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
      visit edit_user_registration_path(locale: I18n.default_locale)

      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.deletion.title'))
      expect(page).to have_button(I18n.t('better_together.settings.index.my_data.deletion.submit'))
      expect(page).to have_button(I18n.t('better_together.settings.index.my_data.deletion.cancel')) if expect_direct_delete_button
    end

    expect(entry_result[:desktop]).to end_with("docs/screenshots/desktop/#{entry_slug}.png")
    expect(entry_result[:mobile]).to end_with("docs/screenshots/mobile/#{entry_slug}.png")

    next unless ENV['CAPTURE_MY_DATA'] == '1'

    my_data_slug = ENV.fetch('MY_DATA_SLUG', 'person_deletion_my_data')
    ensure_pending_deletion_request!
    seed_artifacts = ensure_personal_export_artifacts!

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
      ensure_platform_manager!
      capybara_login_as_platform_manager
      expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
      visit settings_my_data_path(locale: I18n.default_locale)

      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.title'))
      expect(page).to have_text(I18n.t('better_together.settings.index.my_data.exports.title'))
      expect(page).to have_link(I18n.t('better_together.settings.index.my_data.exports.download'))
      expect(page).to have_no_text(I18n.t('better_together.settings.index.my_data.deletion.title'))
    end

    expect(my_data_result[:desktop]).to end_with("docs/screenshots/desktop/#{my_data_slug}.png")
    expect(my_data_result[:mobile]).to end_with("docs/screenshots/mobile/#{my_data_slug}.png")

    next unless ENV['CAPTURE_SEED_ARCHITECTURE'] == '1'

    seed_index_slug = ENV.fetch('PERSON_SEEDS_INDEX_SLUG', 'person_deletion_person_seeds_index')
    seed_index_result = BetterTogether::CapybaraScreenshotEngine.capture(
      seed_index_slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'person_deletion_review',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      ensure_platform_manager!
      capybara_login_as_platform_manager
      visit person_seeds_path(locale: I18n.default_locale)

      expect(page).to have_text(I18n.t('person_seeds.index.title'))
      expect(page).to have_button(I18n.t('person_seeds.index.new_export'))
      expect(page).to have_text(seed_artifacts[:seed].identifier)
    end

    expect(seed_index_result[:desktop]).to end_with("docs/screenshots/desktop/#{seed_index_slug}.png")
    expect(seed_index_result[:mobile]).to end_with("docs/screenshots/mobile/#{seed_index_slug}.png")

    seed_detail_slug = ENV.fetch('PERSON_SEED_DETAIL_SLUG', 'person_deletion_person_seed_detail')
    seed_detail_result = BetterTogether::CapybaraScreenshotEngine.capture(
      seed_detail_slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'person_deletion_review',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      ensure_platform_manager!
      capybara_login_as_platform_manager
      visit person_seed_path(seed_artifacts[:seed], locale: I18n.default_locale)

      expect(page).to have_text(seed_artifacts[:seed].identifier)
      expect(page).to have_text(I18n.t('seeds.show.origin'))
      expect(page).to have_text(I18n.t('seeds.show.payload'))
      expect(page).to have_link(I18n.t('seeds.show.download_yaml'))
    end

    expect(seed_detail_result[:desktop]).to end_with("docs/screenshots/desktop/#{seed_detail_slug}.png")
    expect(seed_detail_result[:mobile]).to end_with("docs/screenshots/mobile/#{seed_detail_slug}.png")
  end
end
